//
//  MTIMPSUnsharpMaskFilter.swift
//  MetalPetal
//

import Foundation
import Metal

public final class MTIMPSUnsharpMaskFilter: MTIUnaryFilter {
    public var inputImage: MTIImage? {
        didSet {
            gaussianBlurFilter.inputImage = inputImage
        }
    }

    public var outputPixelFormat: MTLPixelFormat = .unspecified

    /// (0, 1]. Default is 0.5.
    public var scale: Float = 0.5

    public var radius: Float = 2.0 {
        didSet {
            gaussianBlurFilter.radius = radius
        }
    }

    /// [0, 1). Default is 0.
    public var threshold: Float = 0
    private let gaussianBlurFilter = MTIMPSGaussianBlurFilter()

    public init() {
        gaussianBlurFilter.radius = radius
    }

    private static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .init(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: .init(name: "usmSecondPass")
    )

    public var outputImage: MTIImage? {
        guard let inputImage, let blurImage = gaussianBlurFilter.outputImage else {
            return nil
        }
        return MTIMPSUnsharpMaskFilter.kernel.apply(
            to: [inputImage, blurImage],
            parameters: ["scale": .float(scale),
                         "threshold": .float(threshold)],
            outputDimensions: MTITextureDimensions(cgSize: inputImage
                .size),
            outputPixelFormat: outputPixelFormat
        )
    }
}
