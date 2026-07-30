//
//  MTIRenderPipelineKernel+Apply.swift
//  Pods
//
//  Created by YuAo on 2021/11/30.
//

import Foundation
import Metal

public extension MTIRenderPipelineKernel {
    func makeImage(
        parameters: [String: Any] = [:],
        dimensions: MTITextureDimensions,
        pixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        apply(to: [], parameters: parameters, outputDimensions: dimensions, outputPixelFormat: pixelFormat)
    }

    func apply(
        to image: MTIImage,
        parameters: [String: Any] = [:],
        outputPixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        __apply(
            toInputImages: [image],
            parameters: parameters,
            outputTextureDimensions: image.dimensions,
            outputPixelFormat: outputPixelFormat
        )
    }

    func apply(
        to image: MTIImage,
        parameters: [String: Any] = [:],
        outputDimensions: MTITextureDimensions,
        outputPixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        __apply(
            toInputImages: [image],
            parameters: parameters,
            outputTextureDimensions: outputDimensions,
            outputPixelFormat: outputPixelFormat
        )
    }

    func apply(
        to images: [MTIImage],
        parameters: [String: Any] = [:],
        outputDimensions: MTITextureDimensions,
        outputPixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        __apply(
            toInputImages: images,
            parameters: parameters,
            outputTextureDimensions: outputDimensions,
            outputPixelFormat: outputPixelFormat
        )
    }

    func apply(
        to images: [MTIImage],
        parameters: [String: Any] = [:],
        outputDescriptors: [MTIRenderPassOutputDescriptor]
    ) -> [MTIImage] {
        __apply(toInputImages: images, parameters: parameters, outputDescriptors: outputDescriptors)
    }

    @available(*, deprecated, renamed: "apply(to:parameters:outputDescriptors:)")
    func apply(
        toInputImages: [MTIImage],
        parameters: [String: Any],
        outputDescriptors: [MTIRenderPassOutputDescriptor]
    ) -> [MTIImage] {
        __apply(toInputImages: toInputImages, parameters: parameters, outputDescriptors: outputDescriptors)
    }

    @available(*, deprecated, renamed: "apply(to:parameters:outputDimensions:outputPixelFormat:)")
    func apply(
        toInputImages: [MTIImage],
        parameters: [String: Any],
        outputTextureDimensions: MTITextureDimensions,
        outputPixelFormat: MTLPixelFormat
    ) -> MTIImage {
        __apply(
            toInputImages: toInputImages,
            parameters: parameters,
            outputTextureDimensions: outputTextureDimensions,
            outputPixelFormat: outputPixelFormat
        )
    }
}

public extension [MTIRenderCommand] {
    func makeImage(
        rasterSampleCount: Int = 1,
        dimension: MTITextureDimensions,
        pixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        MTIRenderCommand.images(
            byPerforming: self,
            rasterSampleCount: UInt(rasterSampleCount),
            outputDescriptors: [MTIRenderPassOutputDescriptor(
                dimensions: dimension,
                pixelFormat: pixelFormat
            )]
        ).first!
    }

    func makeImages(rasterSampleCount: Int = 1,
                    outputDescriptors: [MTIRenderPassOutputDescriptor]) -> [MTIImage]
    {
        MTIRenderCommand.images(
            byPerforming: self,
            rasterSampleCount: UInt(rasterSampleCount),
            outputDescriptors: outputDescriptors
        )
    }
}
