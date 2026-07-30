//
//  MTIMPSKernel.swift
//  Pods
//
//  Created by YuAo on 03/08/2017.
//

import Foundation
import Metal

@_exported import MetalPerformanceShaders

public typealias MTIMPSKernelBuilder = (MTLDevice) -> MPSKernel

private final class MTIMPSProcessingRecipe: NSObject, MTIImagePromise {
    private let kernel: MTIMPSKernel
    private let inputImages: [MTIImage]
    private let parameters: [String: Any]
    private let outputPixelFormat: MTLPixelFormat
    let dimensions: MTITextureDimensions
    let alphaType: MTIAlphaType

    init(kernel: MTIMPSKernel,
         inputImages: [MTIImage],
         parameters: [String: Any],
         outputTextureDimensions: MTITextureDimensions,
         outputPixelFormat: MTLPixelFormat)
    {
        assert(kernel.alphaTypeHandlingRule._canHandleAlphaTypes(in: inputImages))
        self.inputImages = inputImages
        self.kernel = kernel
        self.parameters = parameters
        dimensions = outputTextureDimensions
        self.outputPixelFormat = outputPixelFormat
        alphaType = kernel.alphaTypeHandlingRule.outputAlphaType(forInputImages: inputImages)
        super.init()
    }

    var dependencies: [MTIImage] {
        inputImages
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        // May need to get a copy
        guard let kernel = try renderingContext.context
            .kernelState(for: kernel, configuration: nil) as? MPSKernel
        else {
            throw _MTIErrorCreate(.mpsKernelNotSupported, "MTIErrorMPSKernelNotSupported", nil)
        }
        kernel.setValuesForKeys(parameters)
        let pixelFormat = (outputPixelFormat == .unspecified) ? renderingContext.context
            .workingPixelFormat : outputPixelFormat

        let textureDescriptor = MTITextureDescriptor(pixelFormat: pixelFormat,
                                                     width: dimensions.width,
                                                     height: dimensions.height,
                                                     mipmapped: false,
                                                     usage: [.shaderWrite, .shaderRead],
                                                     resourceOptions: .storageModePrivate)
        let renderTarget = try renderingContext.context
            .makeRenderTarget(reusableTextureDescriptor: textureDescriptor)
        guard let destinationTexture = renderTarget.texture else {
            throw _MTIErrorCreate(.failedToCreateTexture, "MTIErrorFailedToCreateTexture", nil)
        }
        if inputImages.count == 1 {
            let texture = renderingContext.resolvedTexture(for: inputImages[0])
            let encoder = kernel as! MPSUnaryImageKernel
            encoder.encode(
                commandBuffer: renderingContext.commandBuffer,
                sourceTexture: texture,
                destinationTexture: destinationTexture
            )
        } else if inputImages.count == 2 {
            let texture0 = renderingContext.resolvedTexture(for: inputImages[0])
            let texture1 = renderingContext.resolvedTexture(for: inputImages[1])
            let encoder = kernel as! MPSBinaryImageKernel
            encoder.encode(
                commandBuffer: renderingContext.commandBuffer,
                primaryTexture: texture0,
                secondaryTexture: texture1,
                destinationTexture: destinationTexture
            )
        } else {
            throw _MTIErrorCreate(.mpsKernelInputCountMismatch, "MTIErrorMPSKernelInputCountMismatch", nil)
        }
        return renderTarget
    }

    func copy(with _: NSZone? = nil) -> Any {
        self
    }

    func updatingDependencies(_ dependencies: [MTIImage]) -> Self {
        assert(dependencies.count == self.dependencies.count)
        return MTIMPSProcessingRecipe(kernel: kernel,
                                      inputImages: dependencies,
                                      parameters: parameters,
                                      outputTextureDimensions: dimensions,
                                      outputPixelFormat: outputPixelFormat) as! Self
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .processor, content: parameters)
    }
}

public final class MTIMPSKernel: NSObject, MTIKernel {
    private let builder: MTIMPSKernelBuilder
    public let alphaTypeHandlingRule: MTIAlphaTypeHandlingRule

    public convenience init(builder: @escaping MTIMPSKernelBuilder) {
        self.init(builder: builder, alphaTypeHandlingRule: .general)
    }

    public init(builder: @escaping MTIMPSKernelBuilder, alphaTypeHandlingRule: MTIAlphaTypeHandlingRule) {
        self.builder = builder
        self.alphaTypeHandlingRule = alphaTypeHandlingRule
        super.init()
    }

    public func makeKernelState(context: MTIContext, configuration _: MTIKernelConfiguration?) throws -> Any {
        guard context.isMetalPerformanceShadersSupported else {
            throw _MTIErrorCreate(.mpsKernelNotSupported, "MTIErrorMPSKernelNotSupported", nil)
        }
        return builder(context.device)
    }

    public func apply(toInputImages images: [MTIImage],
                      parameters: [String: Any],
                      outputTextureDimensions: MTITextureDimensions,
                      outputPixelFormat: MTLPixelFormat) -> MTIImage
    {
        let receipt = MTIMPSProcessingRecipe(kernel: self,
                                             inputImages: images,
                                             parameters: parameters,
                                             outputTextureDimensions: outputTextureDimensions,
                                             outputPixelFormat: outputPixelFormat)
        return MTIImage(promise: receipt)
    }
}
