//
//  MTIAlphaPremultiplicationFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 30/09/2017.
//

import Foundation
import Metal

public final class MTIUnpremultiplyAlphaFilter: NSObject, MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified

    public static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(
            name: MTIFilterUnpremultiplyAlphaFragmentFunctionName
        ),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: MTIAlphaTypeHandlingRule(
            acceptableAlphaTypes: [.premultiplied],
            outputAlphaType: .nonPremultiplied
        )
    )

    public static func image(byProcessingImage image: MTIImage,
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

    public static func image(byProcessingImage image: MTIImage) -> MTIImage {
        self.image(byProcessingImage: image, outputPixelFormat: .unspecified)
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return MTIUnpremultiplyAlphaFilter.image(
            byProcessingImage: inputImage,
            outputPixelFormat: outputPixelFormat
        )
    }
}

public final class MTIPremultiplyAlphaFilter: NSObject, MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified

    public static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(
            name: MTIFilterPremultiplyAlphaFragmentFunctionName
        ),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: MTIAlphaTypeHandlingRule(
            acceptableAlphaTypes: [.nonPremultiplied],
            outputAlphaType: .premultiplied
        )
    )

    public static func image(byProcessingImage image: MTIImage,
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

    public static func image(byProcessingImage image: MTIImage) -> MTIImage {
        self.image(byProcessingImage: image, outputPixelFormat: .unspecified)
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return MTIPremultiplyAlphaFilter.image(
            byProcessingImage: inputImage,
            outputPixelFormat: outputPixelFormat
        )
    }
}
