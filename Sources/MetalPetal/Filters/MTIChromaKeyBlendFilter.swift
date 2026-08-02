//
//  MTIChromaKeyBlendFilter.swift
//  MetalPetal
//

import Foundation
import Metal

public final class MTIChromaKeyBlendFilter: MTIFilter {
    public var inputImage: MTIImage?
    public var inputBackgroundImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var thresholdSensitivity: Float = 0.4
    public var smoothing: Float = 0.1
    public var color = MTIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)

    public init() {}

    private static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "chromaKeyBlend")
    )

    public var outputImage: MTIImage? {
        guard let inputImage, let inputBackgroundImage else {
            return nil
        }
        return MTIChromaKeyBlendFilter.kernel.apply(
            to: [inputImage, inputBackgroundImage],
            parameters: ["color": .vector(MTIVector(value: color.toFloat4())),
                         "thresholdSensitivity": .float(thresholdSensitivity),
                         "smoothing": .float(smoothing)],
            outputDimensions: MTITextureDimensions(cgSize: inputImage.size),
            outputPixelFormat: outputPixelFormat
        )
    }
}
