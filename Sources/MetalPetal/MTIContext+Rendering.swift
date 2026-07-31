//
//  MTIContext+Rendering.swift
//  Pods
//
//  Created by YuAo on 23/07/2017.
//

import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import Metal
import ObjectiveC
import VideoToolbox

private var MTICIImageMTIImageAssociationKey: UInt8 = 0

public extension MTIContext {
    private static var premultiplyAlphaKernel: MTIRenderPipelineKernel {
        MTIPremultiplyAlphaFilter.kernel
    }

    private static var unpremultiplyAlphaKernel: MTIRenderPipelineKernel {
        MTIUnpremultiplyAlphaFilter.kernel
    }

    private static var passthroughKernel: MTIRenderPipelineKernel {
        MTIRenderPipelineKernel.passthrough
    }

    func render(_ image: MTIImage, toDrawableWithRequest request: MTIDrawableRenderingRequest) throws {
        _ = try startTask(toRender: image, toDrawableWithRequest: request, completion: nil)
    }

    func makeCIImage(from image: MTIImage, options: MTICIImageCreationOptions) throws -> CIImage {
        lockForRendering()
        defer {
            unlockForRendering()
        }
        let renderingContext = MTIImageRenderingContext(context: self)
        let persistentImage = image.withCachePolicy(.persistent)
        let resolution = try renderingContext.resolution(for: persistentImage)
        defer {
            resolution.markAsConsumed(by: self)
        }
        renderingContext.commandBuffer.commit()
        renderingContext.commandBuffer.waitUntilScheduled()
        let colorSpace: CGColorSpace = options.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        var ciImage = CIImage(
            mtlTexture: resolution.texture,
            options: [CIImageOption.colorSpace: colorSpace]
        )!
        if options.isFlipped {
            ciImage = ciImage.oriented(forExifOrientation: 4)
        }
        if image.alphaType == .nonPremultiplied {
            // ref: https://developer.apple.com/documentation/coreimage/ciimage/1645894-premultiplyingalpha
            // Premultiplied alpha speeds up the rendering of images, so Core Image filters require that input
            // image data be premultiplied. If you have an image without premultiplied alpha that you want to
            // feed into a filter, use this method before applying the filter.
            ciImage = ciImage.premultiplyingAlpha()
        }
        objc_setAssociatedObject(
            ciImage,
            &MTICIImageMTIImageAssociationKey,
            persistentImage,
            .OBJC_ASSOCIATION_RETAIN
        )
        return ciImage
    }

    func makeCIImage(from image: MTIImage) throws -> CIImage {
        try makeCIImage(from: image, options: MTICIImageCreationOptions.default)
    }

    func render(_ image: MTIImage, to pixelBuffer: CVPixelBuffer, sRGB: Bool) throws {
        _ = try startTask(toRender: image, to: pixelBuffer, sRGB: sRGB, completion: nil)
    }

    func render(_ image: MTIImage, to pixelBuffer: CVPixelBuffer) throws {
        try render(image, to: pixelBuffer, sRGB: false)
    }

    func makeCGImage(from image: MTIImage) throws -> CGImage {
        try makeCGImage(from: image, colorSpace: nil)
    }

    func makeCGImage(from image: MTIImage, sRGB: Bool) throws -> CGImage {
        var outImage: CGImage?
        _ = try startTask(toCreate: &outImage, from: image, sRGB: sRGB)
        return outImage!
    }

    func makeCGImage(from image: MTIImage, colorSpace: CGColorSpace?) throws -> CGImage {
        var outImage: CGImage?
        _ = try startTask(toCreate: &outImage, from: image, colorSpace: colorSpace)
        return outImage!
    }

    func startTask(toCreate outImage: UnsafeMutablePointer<CGImage?>, from image: MTIImage,
                   sRGB: Bool) throws -> MTIRenderTask
    {
        try startTask(toCreate: outImage, from: image, sRGB: sRGB, completion: nil)
    }

    func startTask(toRender image: MTIImage, to pixelBuffer: CVPixelBuffer,
                   sRGB: Bool) throws -> MTIRenderTask
    {
        try startTask(toRender: image, to: pixelBuffer, sRGB: sRGB, completion: nil)
    }

    func startTask(toRender image: MTIImage,
                   toDrawableWithRequest request: MTIDrawableRenderingRequest) throws -> MTIRenderTask
    {
        try startTask(toRender: image, toDrawableWithRequest: request, completion: nil)
    }

    func startTask(
        toRender image: MTIImage,
        to pixelBuffer: CVPixelBuffer,
        sRGB: Bool,
        completion: ((MTIRenderTask) -> Void)?
    ) throws -> MTIRenderTask {
        try startTask(
            toRender: image,
            to: pixelBuffer,
            sRGB: sRGB,
            destinationAlphaType: .premultiplied,
            completion: completion
        )
    }

    func startTask(
        toRender image: MTIImage,
        to pixelBuffer: CVPixelBuffer,
        sRGB: Bool,
        destinationAlphaType: MTIAlphaType,
        completion: ((MTIRenderTask) -> Void)?
    ) throws -> MTIRenderTask {
        lockForRendering()
        defer {
            unlockForRendering()
        }
        let renderingContext = MTIImageRenderingContext(context: self)
        let resolution = try renderingContext.resolution(for: image)
        defer {
            resolution.markAsConsumed(by: self)
        }
        let pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let targetPixelFormat: MTLPixelFormat
        switch pixelFormatType {
        case kCVPixelFormatType_32BGRA:
            targetPixelFormat = sRGB ? .bgra8Unorm_srgb : .bgra8Unorm
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            if isYCbCrPixelFormatSupported {
                targetPixelFormat = sRGB ? .yCbCr8_420_2p_srgb : .yCbCr8_420_2p
            } else {
                throw MTIError(
                    code: .unsupportedCVPixelBufferFormat,
                    message: "MTIErrorUnsupportedCVPixelBufferFormat"
                )
            }
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
             kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
            if isYCbCrPixelFormatSupported {
                targetPixelFormat = sRGB ? .yCbCr10_420_2p_srgb : .yCbCr10_420_2p
            } else {
                throw MTIError(
                    code: .unsupportedCVPixelBufferFormat,
                    message: "MTIErrorUnsupportedCVPixelBufferFormat"
                )
            }
        case kCVPixelFormatType_64RGBAHalf:
            targetPixelFormat = .rgba16Float
        case kCVPixelFormatType_128RGBAFloat:
            targetPixelFormat = .rgba32Float
        case kCVPixelFormatType_OneComponent8:
            #if os(iOS) && !targetEnvironment(macCatalyst)
            targetPixelFormat = sRGB ? .r8Unorm_srgb : .r8Unorm
            #else
            if sRGB {
                throw MTIError(
                    code: .unsupportedCVPixelBufferFormat,
                    message: "MTIErrorUnsupportedCVPixelBufferFormat"
                )
            }
            targetPixelFormat = .r8Unorm
            #endif
        case kCVPixelFormatType_OneComponent16Half:
            targetPixelFormat = .r16Float
        case kCVPixelFormatType_OneComponent32Float:
            targetPixelFormat = .r32Float
        default:
            throw MTIError(
                code: .unsupportedCVPixelBufferFormat,
                message: "MTIErrorUnsupportedCVPixelBufferFormat"
            )
        }
        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: targetPixelFormat,
            width: frameWidth,
            height: frameHeight,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .renderTarget]
        let renderTexture = try coreVideoTextureBridge.makeTexture(
            with: pixelBuffer,
            textureDescriptor: textureDescriptor,
            planeIndex: 0
        )
        let metalTexture = renderTexture.texture
        if resolution.texture.pixelFormat == targetPixelFormat,
           image.alphaType == destinationAlphaType || image.alphaType == .alphaIsOne,
           resolution.texture.width == frameWidth,
           resolution.texture.height == frameHeight
        {
            // Blit
            let blitCommandEncoder = renderingContext.commandBuffer.makeBlitCommandEncoder()
            blitCommandEncoder?.copy(from: resolution.texture,
                                     sourceSlice: 0,
                                     sourceLevel: 0,
                                     sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                     sourceSize: MTLSize(
                                         width: resolution.texture.width,
                                         height: resolution.texture.height,
                                         depth: resolution.texture.depth
                                     ),
                                     to: metalTexture,
                                     destinationSlice: 0,
                                     destinationLevel: 0,
                                     destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            blitCommandEncoder?.endEncoding()
            let task = MTIRenderTask(commandBuffer: renderingContext.commandBuffer)
            if let completion {
                renderingContext.commandBuffer.addCompletedHandler { _ in completion(task) }
            }
            renderingContext.commandBuffer.commit()
            renderingContext.commandBuffer.waitUntilScheduled()
            return task
        } else {
            // Render
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = metalTexture
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            let vertices = MTIVertices.squareVertices(for: CGRect(x: -1, y: -1, width: 2, height: 2))
            // Prefers premultiplied alpha here.
            let kernel: MTIRenderPipelineKernel = if image.alphaType == .nonPremultiplied,
                                                     destinationAlphaType == .premultiplied
            {
                MTIContext.premultiplyAlphaKernel
            } else if image.alphaType == .premultiplied, destinationAlphaType == .nonPremultiplied {
                MTIContext.unpremultiplyAlphaKernel
            } else {
                MTIContext.passthroughKernel
            }
            let configuration = MTIRenderPipelineKernelConfiguration(colorAttachmentPixelFormat: metalTexture
                .pixelFormat)
            guard let renderPipeline = try kernelState(for: kernel,
                                                       configuration: configuration) as? MTIRenderPipeline
            else {
                throw MTIError(
                    code: .failedToCreateCommandEncoder,
                    message: "MTIErrorFailedToCreateCommandEncoder"
                )
            }
            let samplerState = try samplerState(with: image.samplerDescriptor)
            let commandEncoder = renderingContext.commandBuffer
                .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            commandEncoder.setRenderPipelineState(renderPipeline.state)
            commandEncoder.setFragmentTexture(resolution.texture, index: 0)
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)
            vertices.encodeDrawCall(with: commandEncoder, context: renderPipeline)
            commandEncoder.endEncoding()
            let task = MTIRenderTask(commandBuffer: renderingContext.commandBuffer)
            if let completion {
                renderingContext.commandBuffer.addCompletedHandler { _ in completion(task) }
            }
            renderingContext.commandBuffer.commit()
            renderingContext.commandBuffer.waitUntilScheduled()
            return task
        }
    }

    func startTask(
        toCreate outImage: UnsafeMutablePointer<CGImage?>,
        from image: MTIImage,
        sRGB: Bool,
        completion: ((MTIRenderTask) -> Void)?
    ) throws -> MTIRenderTask {
        var pixelBuffer: CVPixelBuffer?
        let errorCode = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.size.width),
            Int(image.size.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [AnyHashable: Any],
                kCVPixelBufferCGImageCompatibilityKey as String: true,
            ] as CFDictionary,
            &pixelBuffer
        )
        guard errorCode == kCVReturnSuccess, let pixelBuffer else {
            throw MTIError(
                code: .failedToCreateCVPixelBuffer,
                message: "MTIErrorFailedToCreateCVPixelBuffer"
            )
        }
        let renderTask = try startTask(toRender: image, to: pixelBuffer, sRGB: sRGB, completion: completion)
        let returnCode = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: outImage)
        if returnCode != noErr {
            throw MTIError(
                code: .failedToCreateCGImageFromCVPixelBuffer,
                message: "MTIErrorFailedToCreateCGImageFromCVPixelBuffer"
            )
        }
        return renderTask
    }

    func startTask(
        toCreate outImage: UnsafeMutablePointer<CGImage?>,
        from image: MTIImage,
        colorSpace: CGColorSpace?
    ) throws -> MTIRenderTask {
        try startTask(toCreate: outImage, from: image, colorSpace: colorSpace, completion: nil)
    }

    func startTask(
        toCreate outImage: UnsafeMutablePointer<CGImage?>,
        from image: MTIImage,
        colorSpace: CGColorSpace?,
        completion: ((MTIRenderTask) -> Void)?
    ) throws -> MTIRenderTask {
        var pixelBuffer: CVPixelBuffer?
        let errorCode = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.size.width),
            Int(image.size.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [AnyHashable: Any],
                kCVPixelBufferCGImageCompatibilityKey as String: true,
            ] as CFDictionary,
            &pixelBuffer
        )
        guard errorCode == kCVReturnSuccess, let pixelBuffer else {
            throw MTIError(
                code: .failedToCreateCVPixelBuffer,
                message: "MTIErrorFailedToCreateCVPixelBuffer"
            )
        }
        let cs = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferCGColorSpaceKey, cs, .shouldPropagate)
        let renderTask = try startTask(toRender: image, to: pixelBuffer, sRGB: false, completion: completion)
        let returnCode = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: outImage)
        if returnCode != noErr {
            throw MTIError(
                code: .failedToCreateCGImageFromCVPixelBuffer,
                message: "MTIErrorFailedToCreateCGImageFromCVPixelBuffer"
            )
        }
        return renderTask
    }

    func startTask(
        toRender image: MTIImage,
        toDrawableWithRequest request: MTIDrawableRenderingRequest,
        completion: ((MTIRenderTask) -> Void)?
    ) throws -> MTIRenderTask {
        lockForRendering()
        defer {
            unlockForRendering()
        }
        let drawableProvider = request.drawableProvider
        let renderingContext = MTIImageRenderingContext(context: self)
        let resolution = try renderingContext.resolution(for: image)
        defer {
            resolution.markAsConsumed(by: self)
        }
        guard let renderPassDescriptor = drawableProvider?.renderPassDescriptor(for: request) else {
            throw MTIError(code: .emptyDrawable, message: "MTIErrorEmptyDrawable")
        }
        if renderPassDescriptor.colorAttachments[0].texture == nil {
            throw MTIError(code: .emptyDrawableTexture, message: "MTIErrorEmptyDrawableTexture")
        }
        var heightScaling: Float = 1.0
        var widthScaling: Float = 1.0
        let drawableSize = CGSize(
            width: renderPassDescriptor.colorAttachments[0].texture!.width,
            height: renderPassDescriptor.colorAttachments[0].texture!.height
        )
        let bounds = CGRect(x: 0, y: 0, width: drawableSize.width, height: drawableSize.height)
        let insetRect = AVMakeRect(aspectRatio: image.size, insideRect: bounds)
        switch request.resizingMode {
        case .scale:
            widthScaling = 1.0
            heightScaling = 1.0
        case .aspect:
            widthScaling = Float(insetRect.size.width / drawableSize.width)
            heightScaling = Float(insetRect.size.height / drawableSize.height)
        case .aspectFill:
            widthScaling = Float(drawableSize.height / insetRect.size.height)
            heightScaling = Float(drawableSize.width / insetRect.size.width)
        @unknown default:
            widthScaling = 1.0
            heightScaling = 1.0
        }
        let vertices = MTIVertices(vertices: [
            MTIVertex(position: (-widthScaling, -heightScaling, 0, 1), textureCoordinate: (0, 1)),
            MTIVertex(position: (widthScaling, -heightScaling, 0, 1), textureCoordinate: (1, 1)),
            MTIVertex(position: (-widthScaling, heightScaling, 0, 1), textureCoordinate: (0, 0)),
            MTIVertex(position: (widthScaling, heightScaling, 0, 1), textureCoordinate: (1, 0)),
        ], primitiveType: .triangleStrip)
        // iOS drawables always require premultiplied alpha.
        let kernel: MTIRenderPipelineKernel = if image.alphaType == .nonPremultiplied {
            MTIContext.premultiplyAlphaKernel
        } else {
            MTIContext.passthroughKernel
        }
        let configuration =
            MTIRenderPipelineKernelConfiguration(colorAttachmentPixelFormat: renderPassDescriptor
                .colorAttachments[0].texture!.pixelFormat)
        guard let renderPipeline = try kernelState(for: kernel,
                                                   configuration: configuration) as? MTIRenderPipeline
        else {
            throw MTIError(
                code: .failedToCreateCommandEncoder,
                message: "MTIErrorFailedToCreateCommandEncoder"
            )
        }
        let samplerState = try samplerState(with: image.samplerDescriptor)
        let commandEncoder = renderingContext.commandBuffer
            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        commandEncoder.setRenderPipelineState(renderPipeline.state)
        commandEncoder.setFragmentTexture(resolution.texture, index: 0)
        commandEncoder.setFragmentSamplerState(samplerState, index: 0)
        vertices.encodeDrawCall(with: commandEncoder, context: renderPipeline)
        commandEncoder.endEncoding()
        if let drawable = drawableProvider?.drawable(for: request) {
            renderingContext.commandBuffer.present(drawable)
        }
        let task = MTIRenderTask(commandBuffer: renderingContext.commandBuffer)
        if let completion {
            renderingContext.commandBuffer.addCompletedHandler { _ in completion(task) }
        }
        renderingContext.commandBuffer.commit()
        renderingContext.commandBuffer.waitUntilScheduled()
        return task
    }

    func startTask(
        toRender image: MTIImage,
        to texture: MTLTexture,
        destinationAlphaType: MTIAlphaType,
        completion: ((MTIRenderTask) -> Void)?
    ) throws -> MTIRenderTask {
        if texture.device !== device {
            throw MTIError(code: .crossDeviceRendering, message: "MTIErrorCrossDeviceRendering")
        }
        lockForRendering()
        defer {
            unlockForRendering()
        }
        let renderingContext = MTIImageRenderingContext(context: self)
        let resolution = try renderingContext.resolution(for: image)
        defer {
            resolution.markAsConsumed(by: self)
        }
        if resolution.texture.pixelFormat == texture.pixelFormat,
           image.alphaType == destinationAlphaType || image.alphaType == .alphaIsOne,
           resolution.texture.width == texture.width,
           resolution.texture.height == texture.height,
           resolution.texture.depth == texture.depth
        {
            // Blit
            let blitCommandEncoder = renderingContext.commandBuffer.makeBlitCommandEncoder()
            blitCommandEncoder?.copy(from: resolution.texture,
                                     sourceSlice: 0,
                                     sourceLevel: 0,
                                     sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                     sourceSize: MTLSize(
                                         width: resolution.texture.width,
                                         height: resolution.texture.height,
                                         depth: resolution.texture.depth
                                     ),
                                     to: texture,
                                     destinationSlice: 0,
                                     destinationLevel: 0,
                                     destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            blitCommandEncoder?.endEncoding()
            let task = MTIRenderTask(commandBuffer: renderingContext.commandBuffer)
            if let completion {
                renderingContext.commandBuffer.addCompletedHandler { _ in completion(task) }
            }
            renderingContext.commandBuffer.commit()
            renderingContext.commandBuffer.waitUntilScheduled()
            return task
        } else {
            // Render
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            let vertices = MTIVertices.squareVertices(for: CGRect(x: -1, y: -1, width: 2, height: 2))
            // Prefers premultiplied alpha here.
            let kernel: MTIRenderPipelineKernel = if image.alphaType == .nonPremultiplied,
                                                     destinationAlphaType == .premultiplied
            {
                MTIContext.premultiplyAlphaKernel
            } else if image.alphaType == .premultiplied, destinationAlphaType == .nonPremultiplied {
                MTIContext.unpremultiplyAlphaKernel
            } else {
                MTIContext.passthroughKernel
            }
            let configuration = MTIRenderPipelineKernelConfiguration(colorAttachmentPixelFormat: texture
                .pixelFormat)
            guard let renderPipeline = try kernelState(for: kernel,
                                                       configuration: configuration) as? MTIRenderPipeline
            else {
                throw MTIError(
                    code: .failedToCreateCommandEncoder,
                    message: "MTIErrorFailedToCreateCommandEncoder"
                )
            }
            let samplerState = try samplerState(with: image.samplerDescriptor)
            let commandEncoder = renderingContext.commandBuffer
                .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            commandEncoder.setRenderPipelineState(renderPipeline.state)
            commandEncoder.setFragmentTexture(resolution.texture, index: 0)
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)
            vertices.encodeDrawCall(with: commandEncoder, context: renderPipeline)
            commandEncoder.endEncoding()
            let task = MTIRenderTask(commandBuffer: renderingContext.commandBuffer)
            if let completion {
                renderingContext.commandBuffer.addCompletedHandler { _ in completion(task) }
            }
            renderingContext.commandBuffer.commit()
            renderingContext.commandBuffer.waitUntilScheduled()
            return task
        }
    }

    /// Render the image to nowhere.
    func startTask(toRender image: MTIImage, completion: ((MTIRenderTask) -> Void)?) throws -> MTIRenderTask {
        lockForRendering()
        defer {
            unlockForRendering()
        }
        let renderingContext = MTIImageRenderingContext(context: self)
        let resolution = try renderingContext.resolution(for: image)
        defer {
            resolution.markAsConsumed(by: self)
        }
        let task = MTIRenderTask(commandBuffer: renderingContext.commandBuffer)
        if let completion {
            renderingContext.commandBuffer.addCompletedHandler { _ in completion(task) }
        }
        renderingContext.commandBuffer.commit()
        renderingContext.commandBuffer.waitUntilScheduled()
        return task
    }
}
