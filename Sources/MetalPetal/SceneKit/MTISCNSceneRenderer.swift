//
//  MTISCNSceneRenderer.swift
//  MetalPetal
//

#if canImport(SceneKit)

import CoreGraphics
import CoreVideo
import Foundation
import Metal

@_exported import AVFoundation
@_exported import SceneKit

public let MTISCNSceneRendererErrorDomain = "MTISCNSceneRendererErrorDomain"

public enum MTISCNSceneRendererError: Int {
    case sceneKitDoesNotSupportMetal = 1001
}

private func sampleCount(for antialiasingMode: SCNAntialiasingMode) -> Int {
    switch antialiasingMode {
    case .none:
        return 1
    case .multisampling2X:
        return 2
    case .multisampling4X:
        return 4
    #if os(macOS)
    case .multisampling8X:
        return 8
    case .multisampling16X:
        return 16
    #endif
    @unknown default:
        return 1
    }
}

private final class MTISCNSceneImagePromise: MTIImagePromise {
    private let pixelFormat: MTLPixelFormat
    private let renderer: SCNRenderer
    private let frameTime: CFTimeInterval
    private let viewport: CGRect
    private let antialiasingMode: SCNAntialiasingMode
    let dimensions: MTITextureDimensions
    let alphaType: MTIAlphaType
    let dependencies: [MTIImage] = []

    init(renderer: SCNRenderer,
         antialiasingMode: SCNAntialiasingMode,
         viewport: CGRect,
         frameTime: CFTimeInterval,
         pixelFormat: MTLPixelFormat,
         isOpaque opaque: Bool)
    {
        dimensions = MTITextureDimensions(cgSize: viewport.size)
        alphaType = opaque ? .alphaIsOne : .premultiplied
        self.pixelFormat = pixelFormat
        self.antialiasingMode = antialiasingMode
        self.renderer = renderer
        self.frameTime = frameTime
        self.viewport = viewport
    }

    func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        guard renderingContext.context.device === renderer.device else {
            throw MTIError(code: .crossDeviceRendering, message: "MTIErrorCrossDeviceRendering")
        }
        var pixelFormat = renderingContext.context.workingPixelFormat
        if self.pixelFormat != .invalid {
            pixelFormat = self.pixelFormat
        }
        let renderTarget = try renderingContext.context
            .makeRenderTarget(reusableTextureDescriptor: MTITextureDescriptor(
                pixelFormat: pixelFormat,
                width: dimensions.width,
                height: dimensions.height,
                mipmapped: false,
                usage: [.renderTarget, .shaderRead],
                resourceOptions: .storageModePrivate
            ))
        var multisampleRenderTarget: MTIImagePromiseRenderTarget?
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        var count = sampleCount(for: antialiasingMode)
        if !renderingContext.context.device.supportsTextureSampleCount(count) {
            count = 1
        }
        if count > 1 {
            let multisampleTextureDescriptor = MTLTextureDescriptor()
            multisampleTextureDescriptor.textureType = .type2DMultisample
            multisampleTextureDescriptor.width = dimensions.width
            multisampleTextureDescriptor.height = dimensions.height
            multisampleTextureDescriptor.depth = dimensions.depth
            multisampleTextureDescriptor.usage = .renderTarget
            multisampleTextureDescriptor.pixelFormat = pixelFormat
            multisampleTextureDescriptor.sampleCount = count
            let multisampleTexture: MTLTexture
            if renderingContext.context.isMemorylessTextureSupported, #available(
                macOS 11.0,
                macCatalyst 14.0,
                iOS 10.0,
                tvOS 10.0,
                *
            ) {
                multisampleTextureDescriptor.storageMode = .memoryless
                guard let texture = renderingContext.context.device
                    .makeTexture(descriptor: multisampleTextureDescriptor)
                else {
                    throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
                }
                multisampleTexture = texture
            } else {
                multisampleTextureDescriptor.storageMode = .private
                let target = try renderingContext.context
                    .makeRenderTarget(reusableTextureDescriptor: multisampleTextureDescriptor
                        .makeMTITextureDescriptor())
                multisampleRenderTarget = target
                guard let texture = target.texture else {
                    throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
                }
                multisampleTexture = texture
            }
            renderPassDescriptor.colorAttachments[0].texture = multisampleTexture
            renderPassDescriptor.colorAttachments[0].resolveTexture = renderTarget.texture
            renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            renderPassDescriptor.colorAttachments[0].texture = renderTarget.texture
            renderPassDescriptor.colorAttachments[0].storeAction = .store
        }
        renderer.render(
            atTime: frameTime,
            viewport: viewport,
            commandBuffer: renderingContext.commandBuffer,
            passDescriptor: renderPassDescriptor
        )
        multisampleRenderTarget?.releaseTexture()
        return renderTarget
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(
            promise: self,
            type: .source,
            content: ["SCNRenderer": renderer, "frameTime": frameTime]
        )
    }
}

public final class MTISCNSceneRenderer {
    private let renderer: SCNRenderer
    private let device: MTLDevice
    private let textureCache: MTICVMetalTextureCache?
    private let commandQueue: MTLCommandQueue?
    private var pool: MTICVPixelBufferPool?
    public var antialiasingMode: SCNAntialiasingMode = .none

    public init(device: MTLDevice) {
        self.device = device
        renderer = SCNRenderer(device: device, options: nil)
        commandQueue = device.makeCommandQueue()
        textureCache = try? MTICVMetalTextureCache(
            device: device,
            cacheAttributes: nil,
            textureAttributes: nil
        )
    }

    public var scene: SCNScene? {
        get { renderer.scene }
        set { renderer.scene = newValue }
    }

    public var scnRenderer: SCNRenderer {
        renderer
    }

    public var nextFrameTime: CFTimeInterval {
        renderer.nextFrameTime
    }

    /// Create a MTImage for the scene at the specified time. The image can only be render with the
    /// MTIContext that shares the same metal device with this renderer.
    public func snapshot(
        atTime time: CFTimeInterval,
        viewport: CGRect,
        pixelFormat: MTLPixelFormat,
        isOpaque: Bool
    ) -> MTIImage {
        let promise = MTISCNSceneImagePromise(renderer: renderer,
                                              antialiasingMode: antialiasingMode,
                                              viewport: viewport,
                                              frameTime: time,
                                              pixelFormat: pixelFormat,
                                              isOpaque: isOpaque)
        return MTIImage(promise: promise)
    }

    /// Render the scene at the specified time to a pixel buffer. The completion block will be called
    /// on an internal queue.
    public func render(
        atTime time: CFTimeInterval,
        viewport: CGRect,
        completion: @escaping (CVPixelBuffer) -> Void
    ) throws {
        try render(atTime: time, viewport: viewport, sRGB: false, completion: completion)
    }

    /// Render the scene at the specified time to a pixel buffer. The completion block will be called
    /// on an internal queue.
    public func render(
        atTime time: CFTimeInterval,
        viewport: CGRect,
        sRGB writesToSRGBTexture: Bool,
        completion: @escaping (CVPixelBuffer) -> Void
    ) throws {
        guard let commandQueue, let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MTIError(
                code: .failedToCreateCommandEncoder,
                message: "MTIErrorFailedToCreateCommandEncoder"
            )
        }
        let width = Int(viewport.size.width)
        let height = Int(viewport.size.height)
        if pool == nil || !(pool!.pixelBufferWidth == width && pool!.pixelBufferHeight == height) {
            pool = try MTICVPixelBufferPool(pixelBufferWidth: width,
                                            pixelBufferHeight: height,
                                            pixelFormatType: kCVPixelFormatType_32BGRA,
                                            minimumBufferCount: 30)
        }
        let pixelBuffer = try pool!.makePixelBuffer(allocationThreshold: 30)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: writesToSRGBTexture ? .bgra8Unorm_srgb : .bgra8Unorm,
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            mipmapped: false
        )
        textureDescriptor.usage = .renderTarget
        guard let textureCache else {
            throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
        }
        let cvMetalTexture = try textureCache.makeTexture(
            with: pixelBuffer,
            textureDescriptor: textureDescriptor,
            planeIndex: 0
        )
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        var count = sampleCount(for: antialiasingMode)
        if !device.supportsTextureSampleCount(count) {
            count = 1
        }
        if count > 1 {
            let multisampleTextureDescriptor = textureDescriptor.copy() as! MTLTextureDescriptor
            multisampleTextureDescriptor.textureType = .type2DMultisample
            multisampleTextureDescriptor.usage = .renderTarget
            multisampleTextureDescriptor.sampleCount = count
            if MTIContext.deviceSupportsMemorylessTexture(device), #available(
                macOS 11.0,
                macCatalyst 14.0,
                iOS 10.0,
                tvOS 10.0,
                *
            ) {
                multisampleTextureDescriptor.storageMode = .memoryless
            } else {
                multisampleTextureDescriptor.storageMode = .private
            }
            guard let multisampleTexture = device.makeTexture(descriptor: multisampleTextureDescriptor) else {
                throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
            }
            renderPassDescriptor.colorAttachments[0].texture = multisampleTexture
            renderPassDescriptor.colorAttachments[0].resolveTexture = cvMetalTexture.texture
            renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            renderPassDescriptor.colorAttachments[0].texture = cvMetalTexture.texture
            renderPassDescriptor.colorAttachments[0].storeAction = .store
        }
        renderer.render(
            atTime: time,
            viewport: viewport,
            commandBuffer: commandBuffer,
            passDescriptor: renderPassDescriptor
        )
        commandBuffer.addCompletedHandler { [weak self] _ in
            completion(pixelBuffer)
            self?.textureCache?.flushCache()
        }
        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
    }
}

#endif
