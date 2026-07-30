//
//  MTIRoundCornerFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/12/20.
//

import Foundation
import Metal
import simd

public final class MTIRoundCornerFilter: NSObject, MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var cornerRadius = MTICornerRadius(topLeft: 0, topRight: 0, bottomRight: 0, bottomLeft: 0)
    public var cornerCurve: MTICornerCurve = .circular

    @available(*, deprecated, message: "Use `cornerRadius` and `cornerCurve` instead.")
    public var radius: simd_float4 {
        get {
            deprecatedRadius
        }
        set {
            deprecatedRadius = newValue
            cornerRadius = MTICornerRadius(
                topLeft: newValue[0],
                topRight: newValue[1],
                bottomRight: newValue[2],
                bottomLeft: newValue[3]
            )
            cornerCurve = .circular
        }
    }

    private var deprecatedRadius = simd_make_float4(0)

    private static let circularCornerKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "circularCorner")
    )

    private static let continuousCornerKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "continuousCorner")
    )

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        let radius = _MTICornerRadiusGetShadingParameterValue(cornerRadius, cornerCurve)
        if radius == simd_make_float4(0) {
            return inputImage
        }
        let kernel: MTIRenderPipelineKernel
        switch cornerCurve {
        case .circular:
            kernel = MTIRoundCornerFilter.circularCornerKernel
        case .continuous:
            kernel = MTIRoundCornerFilter.continuousCornerKernel
        @unknown default:
            assertionFailure("Unsupported MTICornerCurve value.")
            kernel = MTIRoundCornerFilter.circularCornerKernel
        }
        return kernel.apply(to: [inputImage],
                            parameters: ["radius": MTIVector(value: radius)],
                            outputDimensions: inputImage.dimensions,
                            outputPixelFormat: outputPixelFormat)
    }
}
