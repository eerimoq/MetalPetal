//
//  MTIComputePipelineKernel.swift
//  MetalPetal
//
//  Created by Yu Ao on 2018/10/26.
//

import Foundation
import Metal

public final class MTIComputeFunctionDispatchOptions {
    public typealias Generator = (_ pipelineState: MTLComputePipelineState) -> (
        threads: MTLSize,
        threadgroups: MTLSize,
        threadsPerThreadgroup: MTLSize
    )
    let threads: MTLSize
    let threadgroups: MTLSize
    let threadsPerThreadgroup: MTLSize
    let generator: Generator?

    public init(threads: MTLSize, threadgroups: MTLSize, threadsPerThreadgroup: MTLSize) {
        self.threads = threads
        self.threadgroups = threadgroups
        self.threadsPerThreadgroup = threadsPerThreadgroup
        generator = nil
    }

    public init(_ generator: @escaping Generator) {
        threads = MTLSize(width: 0, height: 0, depth: 0)
        threadgroups = MTLSize(width: 0, height: 0, depth: 0)
        threadsPerThreadgroup = MTLSize(width: 0, height: 0, depth: 0)
        self.generator = generator
    }
}

private final class MTIImageComputeRecipe: MTIImagePromise {
    private let inputImages: [MTIImage]
    private let kernel: MTIComputePipelineKernel
    private let dispatchOptions: MTIComputeFunctionDispatchOptions?
    private let functionParameters: [String: MTIFunctionArgumentValue]
    private let outputPixelFormat: MTLPixelFormat
    let dimensions: MTITextureDimensions
    let alphaType: MTIAlphaType

    init(kernel: MTIComputePipelineKernel,
         inputImages: [MTIImage],
         functionParameters: [String: MTIFunctionArgumentValue],
         dispatchOptions: MTIComputeFunctionDispatchOptions?,
         outputTextureDimensions: MTITextureDimensions,
         outputPixelFormat: MTLPixelFormat)
    {
        self.inputImages = inputImages
        self.kernel = kernel
        self.functionParameters = functionParameters
        dimensions = outputTextureDimensions
        self.dispatchOptions = dispatchOptions
        self.outputPixelFormat = outputPixelFormat
        alphaType = kernel.alphaTypeHandlingRule.outputAlphaType(forInputImages: inputImages)
    }

    var dependencies: [MTIImage] {
        inputImages
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        guard let computePipeline = try renderingContext.context.kernelState(
            for: kernel,
            configuration: nil
        ) as? MTIComputePipeline else {
            throw MTIError.failedToCreateCommandEncoder
        }
        let pixelFormat = if outputPixelFormat == .unspecified {
            renderingContext.context.workingPixelFormat
        } else {
            outputPixelFormat
        }
        let textureDescriptor: MTITextureDescriptor
        if dimensions.depth > 1 {
            let mtlTextureDescriptor = MTLTextureDescriptor()
            mtlTextureDescriptor.textureType = .type3D
            mtlTextureDescriptor.width = dimensions.width
            mtlTextureDescriptor.height = dimensions.height
            mtlTextureDescriptor.depth = dimensions.depth
            mtlTextureDescriptor.pixelFormat = pixelFormat
            mtlTextureDescriptor.usage = [.shaderWrite, .shaderRead]
            mtlTextureDescriptor.storageMode = .private
            textureDescriptor = mtlTextureDescriptor.makeMTITextureDescriptor()
        } else {
            textureDescriptor = MTITextureDescriptor(pixelFormat: pixelFormat,
                                                     width: dimensions.width,
                                                     height: dimensions.height,
                                                     mipmapped: false,
                                                     usage: [.shaderWrite, .shaderRead],
                                                     resourceOptions: .storageModePrivate)
        }
        let renderTarget = try renderingContext.context
            .makeRenderTarget(reusableTextureDescriptor: textureDescriptor)

        guard let commandEncoder = renderingContext.commandBuffer.makeComputeCommandEncoder() else {
            throw MTIError.failedToCreateCommandEncoder
        }
        commandEncoder.setComputePipelineState(computePipeline.state)
        var index = 0
        for image in inputImages {
            commandEncoder.setTexture(renderingContext.resolvedTexture(for: image), index: index)
            index += 1
        }
        commandEncoder.setTexture(renderTarget.texture, index: index)
        do {
            try MTIEncodeArguments(bindings: computePipeline.reflection.bindings,
                                   parameters: functionParameters,
                                   functionType: .kernel,
                                   encoder: commandEncoder)
        } catch {
            commandEncoder.endEncoding()
            throw error
        }
        let w = computePipeline.state.threadExecutionWidth
        let h = computePipeline.state.maxTotalThreadsPerThreadgroup / w
        var threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        var threadgroupsPerGrid = MTLSize(width: (dimensions.width + w - 1) / w,
                                          height: (dimensions.height + h - 1) / h,
                                          depth: dimensions.depth)
        var threadsPerGrid = MTLSize(
            width: dimensions.width,
            height: dimensions.height,
            depth: dimensions.depth
        )
        if let dispatchOptions {
            if let generator = dispatchOptions.generator {
                let result = generator(computePipeline.state)
                threadsPerGrid = result.threads
                threadgroupsPerGrid = result.threadgroups
                threadsPerThreadgroup = result.threadsPerThreadgroup
            } else {
                threadsPerGrid = dispatchOptions.threads
                threadgroupsPerGrid = dispatchOptions.threadgroups
                threadsPerThreadgroup = dispatchOptions.threadsPerThreadgroup
            }
        }
        #if os(tvOS)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        #else
        let supportsNonUniformThreadgroupSize: Bool
        #if os(iOS)
        #if targetEnvironment(macCatalyst)
        supportsNonUniformThreadgroupSize = renderingContext.context.device.supportsFamily(.mac2)
        #else
        supportsNonUniformThreadgroupSize = renderingContext.context.device.supportsFamily(.apple4)
        #endif
        #else
        supportsNonUniformThreadgroupSize = renderingContext.context.device.supportsFamily(.mac2)
        #endif
        if supportsNonUniformThreadgroupSize {
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        } else {
            commandEncoder.dispatchThreadgroups(
                threadgroupsPerGrid,
                threadsPerThreadgroup: threadsPerThreadgroup
            )
        }
        #endif
        commandEncoder.endEncoding()
        return renderTarget
    }

    func updatingDependencies(_ dependencies: [MTIImage]) -> Self {
        MTIImageComputeRecipe(kernel: kernel,
                              inputImages: dependencies,
                              functionParameters: functionParameters,
                              dispatchOptions: dispatchOptions,
                              outputTextureDimensions: dimensions,
                              outputPixelFormat: outputPixelFormat) as! Self
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        let content = "\(kernel.computeFunctionDescriptor.name)\n\(functionParameters)\n"
        return MTIImagePromiseDebugInfo(promise: self, type: .processor, content: content)
    }
}

public final class MTIComputePipelineKernel: MTIKernel {
    public let alphaTypeHandlingRule: MTIAlphaTypeHandlingRule
    public let computeFunctionDescriptor: MTIFunctionDescriptor

    public convenience init(computeFunctionDescriptor: MTIFunctionDescriptor) {
        self.init(computeFunctionDescriptor: computeFunctionDescriptor, alphaTypeHandlingRule: .general)
    }

    public init(
        computeFunctionDescriptor: MTIFunctionDescriptor,
        alphaTypeHandlingRule: MTIAlphaTypeHandlingRule
    ) {
        self.computeFunctionDescriptor = computeFunctionDescriptor
        self.alphaTypeHandlingRule = alphaTypeHandlingRule
    }

    public func makeKernelState(context: MTIContext, configuration _: MTIKernelConfiguration?) throws -> Any {
        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        let computeFunction = try context.function(with: computeFunctionDescriptor)
        computePipelineDescriptor.computeFunction = computeFunction
        return try context.computePipeline(with: computePipelineDescriptor)
    }

    public func apply(toInputImages images: [MTIImage],
                      parameters: [String: MTIFunctionArgumentValue],
                      outputTextureDimensions: MTITextureDimensions,
                      outputPixelFormat: MTLPixelFormat) -> MTIImage
    {
        apply(toInputImages: images,
              parameters: parameters,
              dispatchOptions: nil,
              outputTextureDimensions: outputTextureDimensions,
              outputPixelFormat: outputPixelFormat)
    }

    public func apply(toInputImages images: [MTIImage],
                      parameters: [String: MTIFunctionArgumentValue],
                      dispatchOptions: MTIComputeFunctionDispatchOptions?,
                      outputTextureDimensions: MTITextureDimensions,
                      outputPixelFormat: MTLPixelFormat) -> MTIImage
    {
        let receipt = MTIImageComputeRecipe(kernel: self,
                                            inputImages: images,
                                            functionParameters: parameters,
                                            dispatchOptions: dispatchOptions,
                                            outputTextureDimensions: outputTextureDimensions,
                                            outputPixelFormat: outputPixelFormat)
        return MTIImage(promise: receipt)
    }

    public var description: String {
        "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque()); \(computeFunctionDescriptor)>"
    }
}
