//
//  MTIMPSUnsharpMaskFilter.swift
//  MetalPetal
//

import Foundation
import Metal

public final class MTIMPSUnsharpMaskFilter: NSObject, MTIUnaryFilter {
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

    override public init() {
        super.init()
        gaussianBlurFilter.radius = radius
    }

    private static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "usmSecondPass")
    )

    public var outputImage: MTIImage? {
        guard let inputImage, let blurImage = gaussianBlurFilter.outputImage else {
            return nil
        }
        return MTIMPSUnsharpMaskFilter.kernel.apply(to: [inputImage, blurImage],
                                                    parameters: ["scale": scale, "threshold": threshold],
                                                    outputDimensions: MTITextureDimensions(cgSize: inputImage
                                                        .size),
                                                    outputPixelFormat: outputPixelFormat)
    }
}
