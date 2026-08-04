//
//  MTIAlphaPremultiplicationFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 30/09/2017.
//

import Foundation
import Metal

public final class MTIUnpremultiplyAlphaFilter: MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified

    static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .init(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: .init(name: MTIFilterUnpremultiplyAlphaFragmentFunctionName),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: MTIAlphaTypeHandlingRule(
            acceptableAlphaTypes: [.premultiplied],
            outputAlphaType: .nonPremultiplied
        )
    )

    public init() {}

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return MTIUnpremultiplyAlphaFilter.image(
            byProcessingImage: inputImage,
            outputPixelFormat: outputPixelFormat
        )
    }

    static func image(byProcessingImage image: MTIImage,
                      outputPixelFormat pixelFormat: MTLPixelFormat) -> MTIImage
    {
        if image.alphaType == .alphaIsOne || image.alphaType == .nonPremultiplied {
            return image
        }
        return kernel.apply(
            to: [image],
            parameters: [:],
            outputDimensions: image.dimensions,
            outputPixelFormat: pixelFormat
        )
    }

    static func image(byProcessingImage image: MTIImage) -> MTIImage {
        self.image(byProcessingImage: image, outputPixelFormat: .unspecified)
    }
}

public final class MTIPremultiplyAlphaFilter: MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified

    public init() {}

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return MTIPremultiplyAlphaFilter.image(
            byProcessingImage: inputImage,
            outputPixelFormat: outputPixelFormat
        )
    }

    static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .init(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: .init(name: MTIFilterPremultiplyAlphaFragmentFunctionName),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: MTIAlphaTypeHandlingRule(
            acceptableAlphaTypes: [.nonPremultiplied],
            outputAlphaType: .premultiplied
        )
    )

    static func image(byProcessingImage image: MTIImage,
                      outputPixelFormat pixelFormat: MTLPixelFormat) -> MTIImage
    {
        if image.alphaType == .alphaIsOne || image.alphaType == .premultiplied {
            return image
        }
        return kernel.apply(
            to: [image],
            parameters: [:],
            outputDimensions: image.dimensions,
            outputPixelFormat: pixelFormat
        )
    }

    static func image(byProcessingImage image: MTIImage) -> MTIImage {
        self.image(byProcessingImage: image, outputPixelFormat: .unspecified)
    }
}
