//
//  MTIRoundCornerFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/12/20.
//

import Foundation
import Metal
import simd

public final class MTIRoundCornerFilter: MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var cornerRadius = MTICornerRadius(topLeft: 0, topRight: 0, bottomRight: 0, bottomLeft: 0)
    public var cornerCurve: MTICornerCurve = .circular

    public init() {}

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        let radius = cornerRadius.shadingParameterValue(for: cornerCurve)
        if radius == simd_make_float4(0) {
            return inputImage
        }
        let kernel: MTIRenderPipelineKernel = switch cornerCurve {
        case .circular:
            MTIRoundCornerFilter.circularCornerKernel
        case .continuous:
            MTIRoundCornerFilter.continuousCornerKernel
        @unknown default:
            MTIRoundCornerFilter.circularCornerKernel
        }
        return kernel.apply(to: [inputImage],
                            parameters: ["radius": .simd(.float4(radius))],
                            outputDimensions: inputImage.dimensions,
                            outputPixelFormat: outputPixelFormat)
    }

    private static let circularCornerKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .init(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: .init(name: "circularCorner")
    )

    private static let continuousCornerKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .init(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: .init(name: "continuousCorner")
    )
}
