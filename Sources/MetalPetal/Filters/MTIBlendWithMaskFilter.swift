//
//  MTIBlendWithMaskFilter.swift
//  MetalPetal
//

import Foundation
import Metal

public final class MTIBlendWithMaskFilter: MTIFilter {
    public var inputImage: MTIImage?
    public var inputBackgroundImage: MTIImage?
    public var inputMask: MTIMask?
    public var outputPixelFormat: MTLPixelFormat = .unspecified

    public init() {}

    private static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "blendWithMask")
    )

    public var outputImage: MTIImage? {
        guard let inputImage,
              let inputMask,
              let inputBackgroundImage
        else {
            return nil
        }
        let usesOneMinusMaskValue = inputMask.mode == .oneMinusMaskValue
        return MTIBlendWithMaskFilter.kernel.apply(
            to: [inputImage, inputMask.content, inputBackgroundImage],
            parameters: ["maskComponent": .int(Int32(inputMask.component.rawValue)),
                         "usesOneMinusMaskValue": .bool(usesOneMinusMaskValue)],
            outputDimensions: MTITextureDimensions(cgSize: inputBackgroundImage.size),
            outputPixelFormat: outputPixelFormat
        )
    }
}
