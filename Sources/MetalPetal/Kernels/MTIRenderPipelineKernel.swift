//
//  MTIRenderPipelineKernel.swift
//  Pods
//
//  Created by YuAo on 02/07/2017.
//

import Foundation
import Metal
import os

public let MTIRenderPipelineMaximumColorAttachmentCount = 8

public final class MTIRenderPipelineKernelConfiguration: MTIKernelConfiguration, Hashable {
    private let pixelFormats: [MTLPixelFormat]
    public let colorAttachmentCount: Int
    public let depthAttachmentPixelFormat: MTLPixelFormat
    public let stencilAttachmentPixelFormat: MTLPixelFormat
    public let rasterSampleCount: Int

    public var colorAttachmentPixelFormats: [MTLPixelFormat] {
        pixelFormats
    }

    public init(
        colorAttachmentPixelFormats: [MTLPixelFormat],
        depthAttachmentPixelFormat: MTLPixelFormat,
        stencilAttachmentPixelFormat: MTLPixelFormat,
        rasterSampleCount: Int
    ) {
        let count = min(colorAttachmentPixelFormats.count, MTIRenderPipelineMaximumColorAttachmentCount)
        pixelFormats = Array(colorAttachmentPixelFormats.prefix(count))
        colorAttachmentCount = count
        self.depthAttachmentPixelFormat = depthAttachmentPixelFormat
        self.stencilAttachmentPixelFormat = stencilAttachmentPixelFormat
        self.rasterSampleCount = rasterSampleCount
    }

    public convenience init(colorAttachmentPixelFormats: [MTLPixelFormat], count _: Int) {
        self.init(
            colorAttachmentPixelFormats: colorAttachmentPixelFormats,
            depthAttachmentPixelFormat: .invalid,
            stencilAttachmentPixelFormat: .invalid,
            rasterSampleCount: 1
        )
    }

    public convenience init(colorAttachmentPixelFormat: MTLPixelFormat) {
        self.init(
            colorAttachmentPixelFormats: [colorAttachmentPixelFormat],
            depthAttachmentPixelFormat: .invalid,
            stencilAttachmentPixelFormat: .invalid,
            rasterSampleCount: 1
        )
    }

    public static func configuration(colorAttachmentPixelFormats: [MTLPixelFormat],
                                     rasterSampleCount: Int) -> MTIRenderPipelineKernelConfiguration
    {
        MTIRenderPipelineKernelConfiguration(
            colorAttachmentPixelFormats: colorAttachmentPixelFormats,
            depthAttachmentPixelFormat: .invalid,
            stencilAttachmentPixelFormat: .invalid,
            rasterSampleCount: rasterSampleCount
        )
    }

    public func hash(into hasher: inout Hasher) {
        for index in 0 ..< colorAttachmentCount {
            hasher.combine(pixelFormats[index].rawValue)
        }
        hasher.combine(depthAttachmentPixelFormat.rawValue)
        hasher.combine(stencilAttachmentPixelFormat.rawValue)
        hasher.combine(rasterSampleCount)
    }

    public static func == (
        lhs: MTIRenderPipelineKernelConfiguration,
        rhs: MTIRenderPipelineKernelConfiguration
    ) -> Bool {
        if lhs === rhs {
            return true
        }
        guard lhs.colorAttachmentCount == rhs.colorAttachmentCount,
              lhs.rasterSampleCount == rhs.rasterSampleCount,
              lhs.depthAttachmentPixelFormat == rhs.depthAttachmentPixelFormat,
              lhs.stencilAttachmentPixelFormat == rhs.stencilAttachmentPixelFormat
        else {
            return false
        }
        for index in 0 ..< lhs.colorAttachmentCount
            where lhs.pixelFormats[index] != rhs.pixelFormats[index]
        {
            return false
        }
        return true
    }

    public var identifier: AnyHashable {
        self
    }
}

public final class MTIRenderPipelineKernel: MTIKernel {
    public let vertexFunctionDescriptor: MTIFunctionDescriptor
    public let fragmentFunctionDescriptor: MTIFunctionDescriptor
    public let vertexDescriptor: MTLVertexDescriptor?
    public let colorAttachmentCount: Int
    public let alphaTypeHandlingRule: MTIAlphaTypeHandlingRule

    public init(
        vertexFunctionDescriptor: MTIFunctionDescriptor,
        fragmentFunctionDescriptor: MTIFunctionDescriptor,
        vertexDescriptor: MTLVertexDescriptor?,
        colorAttachmentCount: Int,
        alphaTypeHandlingRule: MTIAlphaTypeHandlingRule
    ) {
        self.vertexFunctionDescriptor = vertexFunctionDescriptor
        self.fragmentFunctionDescriptor = fragmentFunctionDescriptor
        self.vertexDescriptor = vertexDescriptor?.copy() as? MTLVertexDescriptor
        self.colorAttachmentCount = colorAttachmentCount
        self.alphaTypeHandlingRule = alphaTypeHandlingRule
    }

    public convenience init(
        vertexFunctionDescriptor: MTIFunctionDescriptor,
        fragmentFunctionDescriptor: MTIFunctionDescriptor
    ) {
        self.init(
            vertexFunctionDescriptor: vertexFunctionDescriptor,
            fragmentFunctionDescriptor: fragmentFunctionDescriptor,
            vertexDescriptor: nil,
            colorAttachmentCount: 1,
            alphaTypeHandlingRule: .general
        )
    }

    public func makeKernelState(context: MTIContext, configuration: MTIKernelConfiguration?) throws -> Any {
        let configuration = configuration as! MTIRenderPipelineKernelConfiguration
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        let vertexFunction = try context.function(with: vertexFunctionDescriptor)
        let fragmentFunction = try context.function(with: fragmentFunctionDescriptor)
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        for index in 0 ..< colorAttachmentCount {
            let colorAttachmentDescriptor = MTLRenderPipelineColorAttachmentDescriptor()
            colorAttachmentDescriptor.pixelFormat = configuration.colorAttachmentPixelFormats[index]
            colorAttachmentDescriptor.isBlendingEnabled = false
            renderPipelineDescriptor.colorAttachments[index] = colorAttachmentDescriptor
        }
        renderPipelineDescriptor.depthAttachmentPixelFormat = configuration.depthAttachmentPixelFormat
        renderPipelineDescriptor.stencilAttachmentPixelFormat = configuration.stencilAttachmentPixelFormat
        renderPipelineDescriptor.rasterSampleCount = configuration.rasterSampleCount
        return try context.renderPipeline(with: renderPipelineDescriptor)
    }

    public var description: String {
        """
        <\(type(of: self)): vertexFunctionDescriptor = \(vertexFunctionDescriptor); \
        fragmentFunctionDescriptor = \(fragmentFunctionDescriptor)>
        """
    }

    func makeOutputImage(
        inputImages images: [MTIImage],
        parameters: [String: MTIFunctionArgumentValue],
        outputTextureDimensions: MTITextureDimensions,
        outputPixelFormat: MTLPixelFormat
    ) -> MTIImage {
        let outputDescriptor = MTIRenderPassOutputDescriptor(
            dimensions: outputTextureDimensions,
            pixelFormat: outputPixelFormat
        )
        return makeOutputImages(
            inputImages: images,
            parameters: parameters,
            outputDescriptors: [outputDescriptor]
        )
        .first!
    }

    func makeOutputImages(
        inputImages images: [MTIImage],
        parameters: [String: MTIFunctionArgumentValue],
        outputDescriptors: [MTIRenderPassOutputDescriptor]
    ) -> [MTIImage] {
        let command = MTIRenderCommand(
            kernel: self,
            geometry: MTIVertices.fullViewportSquare,
            images: images,
            parameters: parameters
        )
        return MTIRenderCommand.images(byPerforming: [command], outputDescriptors: outputDescriptors)
    }

    public static let passthrough = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughFragmentFunctionName),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: .passthrough
    )
}

final class MTIImageRenderingRecipe {
    let renderCommands: [MTIRenderCommand]
    let outputDescriptors: [MTIRenderPassOutputDescriptor]
    let resolutionCache: MTIWeakToStrongObjectsMapTable<MTIImageRenderingContext, NSArray>?
    let resolutionCacheLock: OSAllocatedUnfairLock<Void>?
    let alphaType: MTIAlphaType
    let dependencies: [MTIImage]
    let rasterSampleCount: Int

    init(
        renderCommands: [MTIRenderCommand],
        rasterSampleCount: Int,
        outputDescriptors: [MTIRenderPassOutputDescriptor]
    ) {
        self.renderCommands = renderCommands
        self.outputDescriptors = outputDescriptors
        self.rasterSampleCount = rasterSampleCount
        if renderCommands.count == 0 {
            dependencies = []
        } else if renderCommands.count == 1 {
            dependencies = renderCommands[0].images
        } else {
            var dependencies: [MTIImage] = []
            for command in renderCommands {
                dependencies.append(contentsOf: command.images)
            }
            self.dependencies = dependencies
        }
        let lastCommand = renderCommands.last!
        alphaType = lastCommand.kernel.alphaTypeHandlingRule
            .outputAlphaType(forInputImages: lastCommand.images)
        if outputDescriptors.count > 1 {
            resolutionCache = MTIWeakToStrongObjectsMapTable<MTIImageRenderingContext, NSArray>()
            resolutionCacheLock = OSAllocatedUnfairLock()
        } else {
            resolutionCache = nil
            resolutionCacheLock = nil
        }
    }

    func resolve(with renderingContext: MTIImageRenderingContext,
                 resolver _: MTIImagePromise) throws -> [MTIImagePromiseRenderTarget]
    {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let outputCount = outputDescriptors.count
        var pixelFormats = [MTLPixelFormat](repeating: .invalid, count: outputCount)
        var renderTargets: [MTIImagePromiseRenderTarget] = []
        for index in 0 ..< outputCount {
            let outputDescriptor = outputDescriptors[index]
            let pixelFormat = (outputDescriptor.pixelFormat == .unspecified) ? renderingContext.context
                .workingPixelFormat : outputDescriptor.pixelFormat
            pixelFormats[index] = pixelFormat
            let textureDescriptor = MTITextureDescriptor(
                pixelFormat: pixelFormat,
                width: outputDescriptor.dimensions.width,
                height: outputDescriptor.dimensions.height,
                mipmapped: false,
                usage: [.renderTarget, .shaderRead],
                resourceOptions: .storageModePrivate
            )
            let renderTarget = try renderingContext.context
                .makeRenderTarget(reusableTextureDescriptor: textureDescriptor)
            if rasterSampleCount > 1 {
                if renderingContext.context.isMemorylessTextureSupported {
                    let tempTextureDescriptor = textureDescriptor.makeMTLTextureDescriptor()
                    tempTextureDescriptor.textureType = .type2DMultisample
                    tempTextureDescriptor.usage = .renderTarget
                    if #available(macCatalyst 14.0, macOS 11.0, iOS 10.0, tvOS 10.0, *) {
                        tempTextureDescriptor.storageMode = .memoryless
                    }
                    tempTextureDescriptor.sampleCount = rasterSampleCount
                    guard let msaaTexture = renderingContext.context.device
                        .makeTexture(descriptor: tempTextureDescriptor)
                    else {
                        throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
                    }
                    renderPassDescriptor.colorAttachments[index].texture = msaaTexture
                    renderPassDescriptor.colorAttachments[index].clearColor = outputDescriptor.clearColor
                    if outputDescriptor.loadAction == .load {
                        renderPassDescriptor.colorAttachments[index].loadAction = .clear
                    } else {
                        renderPassDescriptor.colorAttachments[index].loadAction = outputDescriptor.loadAction
                    }
                    renderPassDescriptor.colorAttachments[index].storeAction = .multisampleResolve
                    renderPassDescriptor.colorAttachments[index].resolveTexture = renderTarget.texture
                } else {
                    let tempTextureDescriptor = textureDescriptor.makeMTLTextureDescriptor()
                    tempTextureDescriptor.textureType = .type2DMultisample
                    tempTextureDescriptor.usage = .renderTarget
                    tempTextureDescriptor.sampleCount = rasterSampleCount
                    let msaaTarget = try renderingContext.context
                        .makeRenderTarget(reusableTextureDescriptor: tempTextureDescriptor
                            .makeMTITextureDescriptor())
                    renderPassDescriptor.colorAttachments[index].texture = msaaTarget.texture
                    renderPassDescriptor.colorAttachments[index].clearColor = outputDescriptor.clearColor
                    renderPassDescriptor.colorAttachments[index].loadAction = outputDescriptor.loadAction
                    renderPassDescriptor.colorAttachments[index].storeAction = .multisampleResolve
                    renderPassDescriptor.colorAttachments[index].resolveTexture = renderTarget.texture
                    msaaTarget.releaseTexture()
                }
            } else {
                renderPassDescriptor.colorAttachments[index].texture = renderTarget.texture
                renderPassDescriptor.colorAttachments[index].clearColor = outputDescriptor.clearColor
                renderPassDescriptor.colorAttachments[index].loadAction = outputDescriptor.loadAction
                renderPassDescriptor.colorAttachments[index].storeAction = outputDescriptor.storeAction
            }
            renderTargets.append(renderTarget)
        }
        guard let commandEncoder = renderingContext.commandBuffer
            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            throw MTIError(
                code: .failedToCreateCommandEncoder,
                message: "MTIErrorFailedToCreateCommandEncoder"
            )
        }
        for command in renderCommands {
            let configuration = MTIRenderPipelineKernelConfiguration.configuration(
                colorAttachmentPixelFormats: pixelFormats,
                rasterSampleCount: rasterSampleCount
            )
            let renderPipeline: MTIRenderPipeline
            do {
                renderPipeline = try renderingContext.context.kernelState(
                    for: command.kernel,
                    configuration: configuration
                ) as! MTIRenderPipeline
            } catch {
                commandEncoder.endEncoding()
                throw error
            }
            commandEncoder.setRenderPipelineState(renderPipeline.state)
            for argument in renderPipeline.reflection.vertexBindings where argument.type == .texture {
                let index = argument.index
                if index < command.images.count {
                    let texture = renderingContext.resolvedTexture(for: command.images[index])
                    let samplerState = renderingContext.resolvedSamplerState(for: command.images[index])
                    commandEncoder.setVertexTexture(texture, index: index)
                    commandEncoder.setVertexSamplerState(samplerState, index: index)
                } else {
                    commandEncoder.endEncoding()
                    throw MTIError(
                        code: .textureBindingFailed,
                        message: "MTIErrorTextureBindingFailed"
                    )
                }
            }
            for argument in renderPipeline.reflection.fragmentBindings
                where argument.type == .texture
            {
                let index = argument.index
                if index < command.images.count {
                    let texture = renderingContext.resolvedTexture(for: command.images[index])
                    let samplerState = renderingContext.resolvedSamplerState(for: command.images[index])
                    commandEncoder.setFragmentTexture(texture, index: index)
                    commandEncoder.setFragmentSamplerState(samplerState, index: index)
                } else {
                    commandEncoder.endEncoding()
                    throw MTIError(
                        code: .textureBindingFailed,
                        message: "MTIErrorTextureBindingFailed"
                    )
                }
            }
            // encode parameters
            if command.parameters.count > 0 {
                do {
                    try MTIFunctionArgumentsEncoder.encode(
                        renderPipeline.reflection.vertexBindings,
                        values: command.parameters,
                        functionType: .vertex,
                        encoder: commandEncoder
                    )
                    try MTIFunctionArgumentsEncoder.encode(
                        renderPipeline.reflection.fragmentBindings,
                        values: command.parameters,
                        functionType: .fragment,
                        encoder: commandEncoder
                    )
                } catch {
                    commandEncoder.endEncoding()
                    throw error
                }
            }
            command.geometry.encodeDrawCall(with: commandEncoder, context: renderPipeline)
        }
        commandEncoder.endEncoding()
        return renderTargets
    }
}

final class MTIImageRenderingPromise: MTIImagePromise {
    let recipe: MTIImageRenderingRecipe
    let outputIndex: Int

    var dependencies: [MTIImage] {
        recipe.dependencies
    }

    init(imageRenderingRecipe recipe: MTIImageRenderingRecipe, outputIndex index: Int) {
        self.recipe = recipe
        outputIndex = index
    }

    var dimensions: MTITextureDimensions {
        recipe.outputDescriptors[outputIndex].dimensions
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        if recipe.outputDescriptors.count == 1 {
            return try recipe.resolve(with: renderingContext, resolver: self)[0]
        } else {
            recipe.resolutionCacheLock!.lock()
            defer {
                recipe.resolutionCacheLock!.unlock()
            }
            if let renderTargets = recipe.resolutionCache!
                .object(forKey: renderingContext) as? [MTIImagePromiseRenderTarget]
            {
                let renderTarget = renderTargets[outputIndex]
                if renderTarget.texture != nil {
                    return renderTarget
                }
            }
            let renderTargets = try recipe.resolve(with: renderingContext, resolver: self)
            recipe.resolutionCache!.setObject(renderTargets as NSArray, forKey: renderingContext)
            return renderTargets[outputIndex]
        }
    }

    var alphaType: MTIAlphaType {
        recipe.alphaType
    }

    func updatingDependencies(_ dependencies: [MTIImage]) -> Self {
        var newCommands: [MTIRenderCommand] = []
        var index = 0
        for command in recipe.renderCommands {
            let deps = Array(dependencies[index ..< (index + command.images.count)])
            index += command.images.count
            newCommands.append(MTIRenderCommand(
                kernel: command.kernel,
                geometry: command.geometry,
                images: deps,
                parameters: command.parameters
            ))
        }
        return MTIImageRenderingPromise(
            imageRenderingRecipe: MTIImageRenderingRecipe(renderCommands: newCommands,
                                                          rasterSampleCount: recipe.rasterSampleCount,
                                                          outputDescriptors: recipe.outputDescriptors),
            outputIndex: outputIndex
        ) as! Self
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        var content = ""
        for command in recipe.renderCommands {
            content += """
            \(command.kernel.vertexFunctionDescriptor.name)\n\
            \(command.kernel.fragmentFunctionDescriptor.name)\n\
            \(command.parameters)\n
            """
        }
        return MTIImagePromiseDebugInfo(promise: self, type: .processor, content: content)
    }
}

public extension MTIRenderCommand {
    static func images(
        byPerforming renderCommands: [MTIRenderCommand],
        outputDescriptors: [MTIRenderPassOutputDescriptor]
    ) -> [MTIImage] {
        images(byPerforming: renderCommands, rasterSampleCount: 1, outputDescriptors: outputDescriptors)
    }

    static func images(
        byPerforming renderCommands: [MTIRenderCommand],
        rasterSampleCount: Int,
        outputDescriptors: [MTIRenderPassOutputDescriptor]
    ) -> [MTIImage] {
        let recipe = MTIImageRenderingRecipe(
            renderCommands: renderCommands,
            rasterSampleCount: rasterSampleCount,
            outputDescriptors: outputDescriptors
        )
        if outputDescriptors.count == 0 {
            return []
        } else if outputDescriptors.count == 1 {
            let promise = MTIImageRenderingPromise(imageRenderingRecipe: recipe, outputIndex: 0)
            return [MTIImage(promise: promise)]
        } else {
            var outputs: [MTIImage] = []
            for index in 0 ..< outputDescriptors.count {
                let promise = MTIImageRenderingPromise(imageRenderingRecipe: recipe, outputIndex: index)
                outputs.append(MTIImage(promise: promise))
            }
            return outputs
        }
    }
}
