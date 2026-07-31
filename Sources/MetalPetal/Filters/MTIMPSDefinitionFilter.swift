//
//  MTIMPSDefinitionFilter.swift
//  MetalPetal
//

import Foundation
import Metal

public final class MTIMPSDefinitionFilter: MTIUnaryFilter {
    public init() {}

    public var inputImage: MTIImage? {
        didSet {
            blurFilter.inputImage = inputImage
        }
    }

    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var intensity: Float = 0
    private let blurFilter = MTIMPSGaussianBlurFilter()
    private static var kernel: MTIRenderPipelineKernel {
        MTIRenderPipelineKernel(
            vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
            fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "clarity")
        )
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        if intensity <= 0 {
            return inputImage
        }
        blurFilter.radius = Float(inputImage.size.width / 1024.0 * 32.0)
        guard let blurredImage = blurFilter.outputImage else {
            return nil
        }
        return MTIMPSDefinitionFilter.kernel.apply(to: [inputImage, blurredImage],
                                                   parameters: ["intensity": intensity],
                                                   outputDimensions: inputImage.dimensions,
                                                   outputPixelFormat: outputPixelFormat)
    }
}
