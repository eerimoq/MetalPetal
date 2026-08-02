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
        parameters: [String: MTIFunctionArgumentValue] = [:],
        dimensions: MTITextureDimensions,
        pixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        apply(to: [], parameters: parameters, outputDimensions: dimensions, outputPixelFormat: pixelFormat)
    }

    func apply(
        to image: MTIImage,
        parameters: [String: MTIFunctionArgumentValue] = [:],
        outputPixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        makeOutputImage(
            inputImages: [image],
            parameters: parameters,
            outputTextureDimensions: image.dimensions,
            outputPixelFormat: outputPixelFormat
        )
    }

    func apply(
        to image: MTIImage,
        parameters: [String: MTIFunctionArgumentValue] = [:],
        outputDimensions: MTITextureDimensions,
        outputPixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        makeOutputImage(
            inputImages: [image],
            parameters: parameters,
            outputTextureDimensions: outputDimensions,
            outputPixelFormat: outputPixelFormat
        )
    }

    func apply(
        to images: [MTIImage],
        parameters: [String: MTIFunctionArgumentValue] = [:],
        outputDimensions: MTITextureDimensions,
        outputPixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        makeOutputImage(
            inputImages: images,
            parameters: parameters,
            outputTextureDimensions: outputDimensions,
            outputPixelFormat: outputPixelFormat
        )
    }

    func apply(
        to images: [MTIImage],
        parameters: [String: MTIFunctionArgumentValue] = [:],
        outputDescriptors: [MTIRenderPassOutputDescriptor]
    ) -> [MTIImage] {
        makeOutputImages(inputImages: images, parameters: parameters, outputDescriptors: outputDescriptors)
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
            rasterSampleCount: rasterSampleCount,
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
            rasterSampleCount: rasterSampleCount,
            outputDescriptors: outputDescriptors
        )
    }
}
