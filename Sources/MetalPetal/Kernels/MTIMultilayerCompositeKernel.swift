//
//  MTIMultilayerCompositeKernel.swift
//  MetalPetal
//
//  Created by YuAo on 27/09/2017.
//

import CoreGraphics
import Foundation
import Metal
import os
import QuartzCore
import simd

private final class MTIMultilayerCompositeKernelConfiguration: MTIKernelConfiguration, Hashable {
    let outputPixelFormat: MTLPixelFormat
    let rasterSampleCount: Int

    init(outputPixelFormat: MTLPixelFormat, rasterSampleCount: Int) {
        self.outputPixelFormat = outputPixelFormat
        self.rasterSampleCount = rasterSampleCount
    }

    var identifier: AnyHashable {
        self
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(outputPixelFormat.rawValue)
        hasher.combine(rasterSampleCount)
    }

    static func == (
        lhs: MTIMultilayerCompositeKernelConfiguration,
        rhs: MTIMultilayerCompositeKernelConfiguration
    ) -> Bool {
        if lhs === rhs {
            return true
        }
        return lhs.outputPixelFormat == rhs.outputPixelFormat
            && lhs.rasterSampleCount == rhs.rasterSampleCount
    }
}

private final class MTILayerRenderPipelineKey: Hashable {
    let blendMode: MTIBlendMode
    private let contentHasPremultipliedAlpha: Bool
    private let hasContentMask: Bool
    private let hasCompositingMask: Bool
    private let hasTintColor: Bool
    private let cornerCurveType: Int16 // none: 0, circular: 1, continuous: 2

    init(layer: MTILayer) {
        blendMode = layer.blendMode
        contentHasPremultipliedAlpha = layer.content.alphaType == .premultiplied
        hasContentMask = layer.mask != nil
        hasCompositingMask = layer.compositingMask != nil
        hasTintColor = layer.tintColor.alpha > 0
        var cornerCurveType: Int16 = switch layer.cornerCurve {
        case .circular:
            1
        case .continuous:
            2
        @unknown default:
            0
        }
        if layer.cornerRadius.isZero {
            cornerCurveType = 0
        }
        self.cornerCurveType = cornerCurveType
    }

    static func == (lhs: MTILayerRenderPipelineKey, rhs: MTILayerRenderPipelineKey) -> Bool {
        lhs.blendMode == rhs.blendMode &&
            lhs.contentHasPremultipliedAlpha == rhs.contentHasPremultipliedAlpha &&
            lhs.hasContentMask == rhs.hasContentMask &&
            lhs.hasCompositingMask == rhs.hasCompositingMask &&
            lhs.hasTintColor == rhs.hasTintColor &&
            lhs.cornerCurveType == rhs.cornerCurveType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(blendMode)
        hasher.combine(contentHasPremultipliedAlpha)
        hasher.combine(hasContentMask)
        hasher.combine(hasCompositingMask)
        hasher.combine(hasTintColor)
        hasher.combine(cornerCurveType)
    }

    func createFragmentFunctionDescriptor(usesProgrammableBlending: Bool) -> MTIFunctionDescriptor? {
        let fragmentFunctionDescriptorForBlending = if usesProgrammableBlending {
            MTIBlendModes.functionDescriptors(for: blendMode)?
                .forMultilayerCompositingFilterWithProgrammableBlending
        } else {
            MTIBlendModes.functionDescriptors(for: blendMode)?
                .forMultilayerCompositingFilterWithoutProgrammableBlending
        }
        guard let descriptor = fragmentFunctionDescriptorForBlending else {
            return nil
        }
        let constants = MTLFunctionConstantValues()
        var contentHasPremultipliedAlpha = contentHasPremultipliedAlpha
        var hasContentMask = hasContentMask
        var hasCompositingMask = hasCompositingMask
        var hasTintColor = hasTintColor
        var cornerCurveType = cornerCurveType
        constants.setConstantValue(
            &contentHasPremultipliedAlpha,
            type: .bool,
            withName: "metalpetal::multilayer_composite_content_premultiplied"
        )
        constants.setConstantValue(
            &hasContentMask,
            type: .bool,
            withName: "metalpetal::multilayer_composite_has_mask"
        )
        constants.setConstantValue(
            &hasCompositingMask,
            type: .bool,
            withName: "metalpetal::multilayer_composite_has_compositing_mask"
        )
        constants.setConstantValue(
            &hasTintColor,
            type: .bool,
            withName: "metalpetal::multilayer_composite_has_tint_color"
        )
        constants.setConstantValue(
            &cornerCurveType,
            type: .short,
            withName: "metalpetal::multilayer_composite_corner_curve_type"
        )
        return descriptor.withConstantValues(constants)
    }
}

private final class MTIMultilayerCompositeKernelState {
    unowned(unsafe) let context: MTIContext
    let rasterSampleCount: Int
    private let colorAttachmentDescriptor: MTLRenderPipelineColorAttachmentDescriptor
    let passthroughRenderPipeline: MTIRenderPipeline
    let unpremultiplyAlphaRenderPipeline: MTIRenderPipeline
    let premultiplyAlphaInPlaceRenderPipeline: MTIRenderPipeline
    let alphaToOneInPlaceRenderPipeline: MTIRenderPipeline
    private let layerPipelineCacheLock = OSAllocatedUnfairLock()
    private var layerPipelines: [MTILayerRenderPipelineKey: MTIRenderPipeline] = [:]

    private static func renderPipeline(
        fragmentFunctionName: String,
        colorAttachmentDescriptor: MTLRenderPipelineColorAttachmentDescriptor,
        rasterSampleCount: Int,
        context: MTIContext
    ) throws -> MTIRenderPipeline {
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        let vertexFunction = try context.function(with: .init(name: MTIFilterPassthroughVertexFunctionName))
        let fragmentFunction = try context.function(with: .init(name: fragmentFunctionName))
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0] = colorAttachmentDescriptor
        renderPipelineDescriptor.depthAttachmentPixelFormat = .invalid
        renderPipelineDescriptor.stencilAttachmentPixelFormat = .invalid
        renderPipelineDescriptor.rasterSampleCount = rasterSampleCount
        return try context.renderPipeline(with: renderPipelineDescriptor)
    }

    init(
        context: MTIContext,
        colorAttachmentDescriptor: MTLRenderPipelineColorAttachmentDescriptor,
        rasterSampleCount: Int
    ) throws {
        self.context = context
        self.rasterSampleCount = rasterSampleCount
        self.colorAttachmentDescriptor = colorAttachmentDescriptor
            .copy() as! MTLRenderPipelineColorAttachmentDescriptor
        passthroughRenderPipeline = try MTIMultilayerCompositeKernelState.renderPipeline(
            fragmentFunctionName: MTIFilterPassthroughFragmentFunctionName,
            colorAttachmentDescriptor: colorAttachmentDescriptor,
            rasterSampleCount: rasterSampleCount,
            context: context
        )
        unpremultiplyAlphaRenderPipeline = try MTIMultilayerCompositeKernelState.renderPipeline(
            fragmentFunctionName: MTIFilterUnpremultiplyAlphaFragmentFunctionName,
            colorAttachmentDescriptor: colorAttachmentDescriptor,
            rasterSampleCount: rasterSampleCount,
            context: context
        )
        let useProgrammableBlending = context.defaultLibrarySupportsProgrammableBlending && context
            .isProgrammableBlendingSupported
        if useProgrammableBlending {
            premultiplyAlphaInPlaceRenderPipeline = try MTIMultilayerCompositeKernelState.renderPipeline(
                fragmentFunctionName: "premultiplyAlphaInPlace",
                colorAttachmentDescriptor: colorAttachmentDescriptor,
                rasterSampleCount: rasterSampleCount,
                context: context
            )
            alphaToOneInPlaceRenderPipeline = try MTIMultilayerCompositeKernelState.renderPipeline(
                fragmentFunctionName: "alphaToOneInPlace",
                colorAttachmentDescriptor: colorAttachmentDescriptor,
                rasterSampleCount: rasterSampleCount,
                context: context
            )
        } else {
            premultiplyAlphaInPlaceRenderPipeline = try MTIMultilayerCompositeKernelState.renderPipeline(
                fragmentFunctionName: "premultiplyAlpha",
                colorAttachmentDescriptor: colorAttachmentDescriptor,
                rasterSampleCount: rasterSampleCount,
                context: context
            )
            alphaToOneInPlaceRenderPipeline = try MTIMultilayerCompositeKernelState.renderPipeline(
                fragmentFunctionName: "alphaToOne",
                colorAttachmentDescriptor: colorAttachmentDescriptor,
                rasterSampleCount: rasterSampleCount,
                context: context
            )
        }
    }

    func renderPipeline(for layer: MTILayer) throws -> MTIRenderPipeline {
        let key = MTILayerRenderPipelineKey(layer: layer)
        layerPipelineCacheLock.lock()
        defer {
            layerPipelineCacheLock.unlock()
        }
        if let pipeline = layerPipelines[key] {
            return pipeline
        }
        let useProgrammableBlending = context.defaultLibrarySupportsProgrammableBlending && context
            .isProgrammableBlendingSupported
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        let vertexFunction = try context.function(with: .init(name: "multilayerCompositeVertexShader"))
        guard let fragmentFunctionDescriptorForBlending = key
            .createFragmentFunctionDescriptor(usesProgrammableBlending: useProgrammableBlending)
        else {
            throw MTIError.blendFunctionNotFound
        }
        let fragmentFunction = try context.function(with: fragmentFunctionDescriptorForBlending)
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0] = colorAttachmentDescriptor
        renderPipelineDescriptor.depthAttachmentPixelFormat = .invalid
        renderPipelineDescriptor.stencilAttachmentPixelFormat = .invalid
        renderPipelineDescriptor.rasterSampleCount = rasterSampleCount
        let pipeline = try context.renderPipeline(with: renderPipelineDescriptor)
        layerPipelines[key] = pipeline
        return pipeline
    }
}

private final class MTIMultilayerCompositingRecipe: MTIImagePromise {
    let backgroundImage: MTIImage
    let kernel: MTIMultilayerCompositeKernel
    let layers: [MTILayer]
    let outputPixelFormat: MTLPixelFormat
    let rasterSampleCount: Int
    let dimensions: MTITextureDimensions
    let dependencies: [MTIImage]
    let alphaType: MTIAlphaType

    init(
        kernel: MTIMultilayerCompositeKernel,
        backgroundImage: MTIImage,
        layers: [MTILayer],
        rasterSampleCount: Int,
        outputAlphaType: MTIAlphaType,
        outputTextureDimensions: MTITextureDimensions,
        outputPixelFormat: MTLPixelFormat
    ) {
        self.backgroundImage = backgroundImage
        alphaType = outputAlphaType
        self.kernel = kernel
        self.layers = layers
        dimensions = outputTextureDimensions
        self.outputPixelFormat = outputPixelFormat
        self.rasterSampleCount = rasterSampleCount
        var dependencies: [MTIImage] = [backgroundImage]
        for layer in layers {
            dependencies.append(layer.content)
            if let compositingMask = layer.compositingMask {
                dependencies.append(compositingMask.content)
            }
            if let mask = layer.mask {
                dependencies.append(mask.content)
            }
        }
        self.dependencies = dependencies
    }

    private func drawVertices(
        forRect rect: CGRect,
        contentRegion: CGRect,
        flipOptions: MTILayer.FlipOptions,
        commandEncoder: MTLRenderCommandEncoder
    ) {
        let l = Float(rect.minX)
        let r = Float(rect.maxX)
        let t = Float(rect.minY)
        let b = Float(rect.maxY)
        var contentL = Float(contentRegion.minX)
        var contentR = Float(contentRegion.maxX)
        var contentT = Float(contentRegion.maxY)
        var contentB = Float(contentRegion.minY)
        if flipOptions.contains(.flipVertically) {
            swap(&contentT, &contentB)
        }
        if flipOptions.contains(.flipHorizontally) {
            swap(&contentL, &contentR)
        }
        var vertices: [MTIMultilayerCompositingLayerVertex] = [
            MTIMultilayerCompositingLayerVertex(
                position: simd_make_float4(l, t, 0, 1),
                textureCoordinate: simd_make_float2(contentL, contentT),
                positionInLayer: simd_make_float2(0, 1)
            ),
            MTIMultilayerCompositingLayerVertex(
                position: simd_make_float4(r, t, 0, 1),
                textureCoordinate: simd_make_float2(contentR, contentT),
                positionInLayer: simd_make_float2(1, 1)
            ),
            MTIMultilayerCompositingLayerVertex(
                position: simd_make_float4(l, b, 0, 1),
                textureCoordinate: simd_make_float2(contentL, contentB),
                positionInLayer: simd_make_float2(0, 0)
            ),
            MTIMultilayerCompositingLayerVertex(
                position: simd_make_float4(r, b, 0, 1),
                textureCoordinate: simd_make_float2(contentR, contentB),
                positionInLayer: simd_make_float2(1, 0)
            ),
        ]
        commandEncoder.setVertexBytes(
            &vertices,
            length: MemoryLayout<MTIMultilayerCompositingLayerVertex>.stride * 4,
            index: 0
        )
        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func shadingParameters(for layer: MTILayer, backgroundImageSize: CGSize,
                                   layerPixelSize: CGSize) -> MTIMultilayerCompositingLayerShadingParameters
    {
        var parameters = MTIMultilayerCompositingLayerShadingParameters()
        parameters.canvasSize = simd_make_float2(
            Float(backgroundImageSize.width),
            Float(backgroundImageSize.height)
        )
        parameters.opacity = layer.opacity
        parameters.compositingMaskComponent = Int32(layer.compositingMask?.component.rawValue ?? 0)
        parameters.compositingMaskUsesOneMinusValue = layer.compositingMask?.mode == .oneMinusMaskValue
        parameters.compositingMaskHasPremultipliedAlpha = layer.compositingMask?.content
            .alphaType == .premultiplied
        parameters.maskComponent = Int32(layer.mask?.component.rawValue ?? 0)
        parameters.maskUsesOneMinusValue = layer.mask?.mode == .oneMinusMaskValue
        parameters.maskHasPremultipliedAlpha = layer.mask?.content.alphaType == .premultiplied
        parameters.tintColor = layer.tintColor.toFloat4()
        parameters.layerSize = simd_make_float2(Float(layerPixelSize.width), Float(layerPixelSize.height))
        parameters.cornerRadius = layer.cornerRadius.shadingParameterValue(for: layer.cornerCurve)
        return parameters
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        let useProgrammableBlending = renderingContext.context
            .defaultLibrarySupportsProgrammableBlending && renderingContext.context
            .isProgrammableBlendingSupported
        if useProgrammableBlending {
            return try resolveProgrammableBlending(with: renderingContext)
        } else {
            return try resolveNoProgrammableBlending(with: renderingContext)
        }
    }

    private func resolveProgrammableBlending(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let pixelFormat = (outputPixelFormat == .unspecified) ? renderingContext.context
            .workingPixelFormat : outputPixelFormat

        let kernelState = try renderingContext.context.kernelState(
            for: kernel,
            configuration: MTIMultilayerCompositeKernelConfiguration(outputPixelFormat: pixelFormat,
                                                                     rasterSampleCount: rasterSampleCount)
        ) as! MTIMultilayerCompositeKernelState
        let textureDescriptor = MTITextureDescriptor(
            pixelFormat: pixelFormat,
            width: dimensions.width,
            height: dimensions.height,
            mipmapped: false,
            usage: [.renderTarget, .shaderRead],
            resourceOptions: .storageModePrivate
        )
        let renderTarget = try renderingContext.context
            .makeRenderTarget(reusableTextureDescriptor: textureDescriptor)
        let renderPassDescriptor = MTLRenderPassDescriptor()
        if rasterSampleCount > 1 {
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
                throw MTIError.failedToCreateTexture
            }
            renderPassDescriptor.colorAttachments[0].texture = msaaTexture
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
            renderPassDescriptor.colorAttachments[0].resolveTexture = renderTarget.texture
        } else {
            renderPassDescriptor.colorAttachments[0].texture = renderTarget.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            renderPassDescriptor.colorAttachments[0].storeAction = .store
        }
        guard let commandEncoder = renderingContext.commandBuffer
            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            throw MTIError.failedToCreateCommandEncoder
        }
        let backgroundPipeline = (backgroundImage.alphaType == .premultiplied) ? kernelState
            .unpremultiplyAlphaRenderPipeline : kernelState.passthroughRenderPipeline
        commandEncoder.setRenderPipelineState(backgroundPipeline.state)
        commandEncoder.setFragmentTexture(renderingContext.resolvedTexture(for: backgroundImage), index: 0)
        commandEncoder.setFragmentSamplerState(
            renderingContext.resolvedSamplerState(for: backgroundImage),
            index: 0
        )
        MTIVertices.fullViewportSquare.encodeDrawCall(with: commandEncoder, context: backgroundPipeline)
        let backgroundImageSize = backgroundImage.size
        for layer in layers {
            let layerPixelSize = layer.sizeInPixel(forBackgroundSize: backgroundImageSize)
            let layerPixelPosition = layer.positionInPixel(forBackgroundSize: backgroundImageSize)
            let renderPipeline: MTIRenderPipeline
            do {
                renderPipeline = try kernelState.renderPipeline(for: layer)
            } catch {
                commandEncoder.endEncoding()
                throw error
            }
            commandEncoder.setRenderPipelineState(renderPipeline.state)
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(
                transform,
                layerPixelPosition.x - backgroundImageSize.width / 2.0,
                -(layerPixelPosition.y - backgroundImageSize.height / 2.0),
                0
            )
            transform = CATransform3DRotate(transform, CGFloat(-layer.rotation), 0, 0, 1)
            var transformMatrix = MTIMakeTransformMatrixFromCATransform3D(transform)
            commandEncoder.setVertexBytes(
                &transformMatrix,
                length: MemoryLayout<simd_float4x4>.stride,
                index: 1
            )
            var orthographicMatrix = MTIMakeOrthographicMatrix(
                Float(-backgroundImageSize.width / 2.0),
                Float(backgroundImageSize.width / 2.0),
                Float(-backgroundImageSize.height / 2.0),
                Float(backgroundImageSize.height / 2.0),
                -1,
                1
            )
            commandEncoder.setVertexBytes(
                &orthographicMatrix,
                length: MemoryLayout<simd_float4x4>.stride,
                index: 2
            )
            commandEncoder.setFragmentTexture(renderingContext.resolvedTexture(for: layer.content), index: 0)
            commandEncoder.setFragmentSamplerState(
                renderingContext.resolvedSamplerState(for: layer.content),
                index: 0
            )
            if let compositingMask = layer.compositingMask {
                commandEncoder.setFragmentTexture(
                    renderingContext.resolvedTexture(for: compositingMask.content),
                    index: 1
                )
                commandEncoder.setFragmentSamplerState(
                    renderingContext.resolvedSamplerState(for: compositingMask.content),
                    index: 1
                )
            }
            if let mask = layer.mask {
                commandEncoder.setFragmentTexture(
                    renderingContext.resolvedTexture(for: mask.content),
                    index: 2
                )
                commandEncoder.setFragmentSamplerState(
                    renderingContext.resolvedSamplerState(for: mask.content),
                    index: 2
                )
            }
            var parameters = shadingParameters(
                for: layer,
                backgroundImageSize: backgroundImageSize,
                layerPixelSize: layerPixelSize
            )
            commandEncoder.setFragmentBytes(
                &parameters,
                length: MemoryLayout<MTIMultilayerCompositingLayerShadingParameters>.stride,
                index: 0
            )
            drawVertices(
                forRect: CGRect(
                    x: -layerPixelSize.width / 2.0,
                    y: -layerPixelSize.height / 2.0,
                    width: layerPixelSize.width,
                    height: layerPixelSize.height
                ),
                contentRegion: CGRect(
                    x: layer.contentRegion.origin.x / layer.content.size.width,
                    y: layer.contentRegion.origin.y / layer.content.size.height,
                    width: layer.contentRegion.size.width / layer.content.size.width,
                    height: layer.contentRegion.size.height / layer.content.size.height
                ),
                flipOptions: layer.contentFlipOptions,
                commandEncoder: commandEncoder
            )
        }
        let outputAlphaTypeRenderPipeline: MTIRenderPipeline? = switch alphaType {
        case .nonPremultiplied:
            nil
        case .alphaIsOne:
            kernelState.alphaToOneInPlaceRenderPipeline
        case .premultiplied:
            kernelState.premultiplyAlphaInPlaceRenderPipeline
        case .unknown:
            nil
        }
        if let outputAlphaTypeRenderPipeline {
            commandEncoder.setRenderPipelineState(outputAlphaTypeRenderPipeline.state)
            MTIVertices.fullViewportSquare.encodeDrawCall(
                with: commandEncoder,
                context: outputAlphaTypeRenderPipeline
            )
        }
        commandEncoder.endEncoding()
        return renderTarget
    }

    private func resolveNoProgrammableBlending(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let pixelFormat = (outputPixelFormat == .unspecified) ? renderingContext.context
            .workingPixelFormat : outputPixelFormat
        let kernelState = try renderingContext.context.kernelState(
            for: kernel,
            configuration: MTIMultilayerCompositeKernelConfiguration(outputPixelFormat: pixelFormat,
                                                                     rasterSampleCount: rasterSampleCount)
        ) as! MTIMultilayerCompositeKernelState
        let textureDescriptor = MTITextureDescriptor(
            pixelFormat: pixelFormat,
            width: dimensions.width,
            height: dimensions.height,
            mipmapped: false,
            usage: [.renderTarget, .shaderRead],
            resourceOptions: .storageModePrivate
        )
        let renderTarget = try renderingContext.context
            .makeRenderTarget(reusableTextureDescriptor: textureDescriptor)
        let renderPassDescriptor = MTLRenderPassDescriptor()
        if rasterSampleCount > 1 {
            let tempTextureDescriptor = textureDescriptor.makeMTLTextureDescriptor()
            tempTextureDescriptor.textureType = .type2DMultisample
            tempTextureDescriptor.usage = .renderTarget
            tempTextureDescriptor.sampleCount = rasterSampleCount
            let msaaTarget = try renderingContext.context
                .makeRenderTarget(reusableTextureDescriptor: tempTextureDescriptor.makeMTITextureDescriptor())
            renderPassDescriptor.colorAttachments[0].texture = msaaTarget.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            renderPassDescriptor.colorAttachments[0].storeAction = .storeAndMultisampleResolve
            renderPassDescriptor.colorAttachments[0].resolveTexture = renderTarget.texture
            msaaTarget.releaseTexture()
        } else {
            renderPassDescriptor.colorAttachments[0].texture = renderTarget.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            renderPassDescriptor.colorAttachments[0].storeAction = .store
        }
        guard var commandEncoder = renderingContext.commandBuffer
            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            throw MTIError.failedToCreateCommandEncoder
        }
        let backgroundPipeline = (backgroundImage.alphaType == .premultiplied) ? kernelState
            .unpremultiplyAlphaRenderPipeline : kernelState.passthroughRenderPipeline
        commandEncoder.setRenderPipelineState(backgroundPipeline.state)
        commandEncoder.setFragmentTexture(renderingContext.resolvedTexture(for: backgroundImage), index: 0)
        commandEncoder.setFragmentSamplerState(
            renderingContext.resolvedSamplerState(for: backgroundImage),
            index: 0
        )
        MTIVertices.fullViewportSquare.encodeDrawCall(with: commandEncoder, context: backgroundPipeline)
        func prepareCommandEncoderForNextDraw() {
            if rasterSampleCount > 1 {
                commandEncoder.endEncoding()
                renderPassDescriptor.colorAttachments[0].loadAction = .load
                commandEncoder = renderingContext.commandBuffer
                    .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            } else {
                #if os(iOS) || targetEnvironment(simulator) || targetEnvironment(macCatalyst) || os(tvOS)
                commandEncoder.endEncoding()
                renderPassDescriptor.colorAttachments[0].loadAction = .load
                commandEncoder = renderingContext.commandBuffer
                    .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
                #else
                commandEncoder.textureBarrier()
                #endif
            }
        }
        let backgroundImageSize = backgroundImage.size
        for layer in layers {
            prepareCommandEncoderForNextDraw()
            if let compositingMask = layer.compositingMask {
                commandEncoder.setFragmentTexture(
                    renderingContext.resolvedTexture(for: compositingMask.content),
                    index: 2
                )
                commandEncoder.setFragmentSamplerState(
                    renderingContext.resolvedSamplerState(for: compositingMask.content),
                    index: 2
                )
            }
            if let mask = layer.mask {
                commandEncoder.setFragmentTexture(
                    renderingContext.resolvedTexture(for: mask.content),
                    index: 3
                )
                commandEncoder.setFragmentSamplerState(
                    renderingContext.resolvedSamplerState(for: mask.content),
                    index: 3
                )
            }
            let layerPixelSize = layer.sizeInPixel(forBackgroundSize: backgroundImageSize)
            let layerPixelPosition = layer.positionInPixel(forBackgroundSize: backgroundImageSize)

            let renderPipeline: MTIRenderPipeline
            do {
                renderPipeline = try kernelState.renderPipeline(for: layer)
            } catch {
                commandEncoder.endEncoding()
                throw error
            }
            commandEncoder.setRenderPipelineState(renderPipeline.state)
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(
                transform,
                layerPixelPosition.x - backgroundImageSize.width / 2.0,
                -(layerPixelPosition.y - backgroundImageSize.height / 2.0),
                0
            )
            transform = CATransform3DRotate(transform, CGFloat(-layer.rotation), 0, 0, 1)
            var transformMatrix = MTIMakeTransformMatrixFromCATransform3D(transform)
            commandEncoder.setVertexBytes(
                &transformMatrix,
                length: MemoryLayout<simd_float4x4>.stride,
                index: 1
            )
            var orthographicMatrix = MTIMakeOrthographicMatrix(
                Float(-backgroundImageSize.width / 2.0),
                Float(backgroundImageSize.width / 2.0),
                Float(-backgroundImageSize.height / 2.0),
                Float(backgroundImageSize.height / 2.0),
                -1,
                1
            )
            commandEncoder.setVertexBytes(
                &orthographicMatrix,
                length: MemoryLayout<simd_float4x4>.stride,
                index: 2
            )
            commandEncoder.setFragmentTexture(renderingContext.resolvedTexture(for: layer.content), index: 0)
            commandEncoder.setFragmentSamplerState(
                renderingContext.resolvedSamplerState(for: layer.content),
                index: 0
            )
            commandEncoder.setFragmentTexture(renderTarget.texture, index: 1)
            var parameters = shadingParameters(
                for: layer,
                backgroundImageSize: backgroundImageSize,
                layerPixelSize: layerPixelSize
            )
            commandEncoder.setFragmentBytes(
                &parameters,
                length: MemoryLayout<MTIMultilayerCompositingLayerShadingParameters>.stride,
                index: 0
            )
            drawVertices(
                forRect: CGRect(
                    x: -layerPixelSize.width / 2.0,
                    y: -layerPixelSize.height / 2.0,
                    width: layerPixelSize.width,
                    height: layerPixelSize.height
                ),
                contentRegion: CGRect(
                    x: layer.contentRegion.origin.x / layer.content.size.width,
                    y: layer.contentRegion.origin.y / layer.content.size.height,
                    width: layer.contentRegion.size.width / layer.content.size.width,
                    height: layer.contentRegion.size.height / layer.content.size.height
                ),
                flipOptions: layer.contentFlipOptions,
                commandEncoder: commandEncoder
            )
        }
        let outputAlphaTypeRenderPipeline: MTIRenderPipeline? = switch alphaType {
        case .nonPremultiplied:
            nil
        case .alphaIsOne:
            kernelState.alphaToOneInPlaceRenderPipeline
        case .premultiplied:
            kernelState.premultiplyAlphaInPlaceRenderPipeline
        case .unknown:
            nil
        }
        if let outputAlphaTypeRenderPipeline {
            prepareCommandEncoderForNextDraw()
            commandEncoder.setRenderPipelineState(outputAlphaTypeRenderPipeline.state)
            commandEncoder.setFragmentTexture(renderTarget.texture, index: 0)
            commandEncoder.setFragmentSamplerState(
                renderingContext.resolvedSamplerState(for: backgroundImage),
                index: 0
            )
            MTIVertices.fullViewportSquare.encodeDrawCall(
                with: commandEncoder,
                context: outputAlphaTypeRenderPipeline
            )
        }
        commandEncoder.endEncoding()
        return renderTarget
    }

    func updatingDependencies(_ dependencies: [MTIImage]) -> Self {
        var pointer = 0
        let backgroundImage = dependencies[pointer]
        pointer += 1
        var newLayers: [MTILayer] = []
        for layer in layers {
            let newContent = dependencies[pointer]
            pointer += 1
            var newCompositingMask: MTIMask?
            var newMask: MTIMask?
            if let compositingMask = layer.compositingMask {
                let newCompositingMaskContent = dependencies[pointer]
                pointer += 1
                newCompositingMask = MTIMask(
                    content: newCompositingMaskContent,
                    component: compositingMask.component,
                    mode: compositingMask.mode
                )
            }
            if let mask = layer.mask {
                let newMaskContent = dependencies[pointer]
                pointer += 1
                newMask = MTIMask(content: newMaskContent, component: mask.component, mode: mask.mode)
            }
            let newLayer = MTILayer(
                content: newContent,
                contentRegion: layer.contentRegion,
                contentFlipOptions: layer.contentFlipOptions,
                mask: newMask,
                compositingMask: newCompositingMask,
                layoutUnit: layer.layoutUnit,
                position: layer.position,
                size: layer.size,
                rotation: layer.rotation,
                opacity: layer.opacity,
                cornerRadius: layer.cornerRadius,
                cornerCurve: layer.cornerCurve,
                tintColor: layer.tintColor,
                blendMode: layer.blendMode
            )
            newLayers.append(newLayer)
        }
        return MTIMultilayerCompositingRecipe(
            kernel: kernel,
            backgroundImage: backgroundImage,
            layers: newLayers,
            rasterSampleCount: rasterSampleCount,
            outputAlphaType: alphaType,
            outputTextureDimensions: dimensions,
            outputPixelFormat: outputPixelFormat
        ) as! Self
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .processor, content: layers)
    }
}

public final class MTIMultilayerCompositeKernel: MTIKernel {
    public init() {}

    public func makeKernelState(context: MTIContext, configuration: MTIKernelConfiguration?) throws -> Any {
        let configuration = configuration as! MTIMultilayerCompositeKernelConfiguration
        let colorAttachmentDescriptor = MTLRenderPipelineColorAttachmentDescriptor()
        colorAttachmentDescriptor.pixelFormat = configuration.outputPixelFormat
        colorAttachmentDescriptor.isBlendingEnabled = false
        return try MTIMultilayerCompositeKernelState(
            context: context,
            colorAttachmentDescriptor: colorAttachmentDescriptor,
            rasterSampleCount: configuration.rasterSampleCount
        )
    }

    public func apply(
        toBackgroundImage image: MTIImage,
        layers: [MTILayer],
        rasterSampleCount: Int,
        outputAlphaType: MTIAlphaType,
        outputTextureDimensions: MTITextureDimensions,
        outputPixelFormat: MTLPixelFormat
    ) -> MTIImage {
        let receipt = MTIMultilayerCompositingRecipe(
            kernel: self,
            backgroundImage: image,
            layers: layers,
            rasterSampleCount: rasterSampleCount,
            outputAlphaType: outputAlphaType,
            outputTextureDimensions: outputTextureDimensions,
            outputPixelFormat: outputPixelFormat
        )
        return MTIImage(promise: receipt)
    }
}

func MTIMultilayerCompositingRenderGraphNodeOptimize(_ node: MTIRenderGraphNode) {
    guard let recipe = node.image?.promise as? MTIMultilayerCompositingRecipe else {
        return
    }
    guard let lastNode = node.inputs?.first, let lastImage = lastNode.image else {
        return
    }
    guard lastNode.uniqueDependentCount == 1,
          let lastPromise = lastImage.promise as? MTIMultilayerCompositingRecipe
    else {
        return
    }
    if lastImage.cachePolicy == .transient, lastPromise.outputPixelFormat == recipe.outputPixelFormat,
       recipe.kernel === lastPromise.kernel
    {
        let layers = lastPromise.layers + recipe.layers
        let promise = MTIMultilayerCompositingRecipe(
            kernel: recipe.kernel,
            backgroundImage: lastPromise.backgroundImage,
            layers: layers,
            rasterSampleCount: max(recipe.rasterSampleCount, lastPromise.rasterSampleCount),
            outputAlphaType: recipe.alphaType,
            outputTextureDimensions: MTITextureDimensions(cgSize: lastPromise.backgroundImage.size),
            outputPixelFormat: recipe.outputPixelFormat
        )
        var inputs = lastNode.inputs ?? []
        node.inputs?.remove(at: 0)
        inputs.append(contentsOf: node.inputs ?? [])
        node.inputs = inputs
        node.image = MTIImage(
            promise: promise,
            samplerDescriptor: node.image!.samplerDescriptor,
            cachePolicy: node.image!.cachePolicy
        )
    }
}
