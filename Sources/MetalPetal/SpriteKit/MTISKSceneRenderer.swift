//
//  MTISKSceneRenderer.swift
//  MetalPetal
//
//  Created by YuAo on 2020/7/24.
//

#if canImport(SpriteKit)

import CoreGraphics
import Foundation
import Metal

@_exported import SpriteKit

private final class MTISKSceneImagePromise: MTIImagePromise {
    private let pixelFormat: MTLPixelFormat
    private let frameTime: TimeInterval
    private let viewport: CGRect
    private let device: MTLDevice?
    private let renderer: SKRenderer?
    private let scene: SKScene?
    let dimensions: MTITextureDimensions
    let alphaType: MTIAlphaType
    let dependencies: [MTIImage] = []

    init(
        renderer: SKRenderer,
        device: MTLDevice,
        viewport: CGRect,
        frameTime: TimeInterval,
        pixelFormat: MTLPixelFormat,
        isOpaque opaque: Bool
    ) {
        self.renderer = renderer
        self.device = device
        scene = nil
        dimensions = MTITextureDimensions(cgSize: viewport.size)
        alphaType = opaque ? .alphaIsOne : .premultiplied
        self.pixelFormat = pixelFormat
        self.frameTime = frameTime
        self.viewport = viewport
    }

    init(
        scene: SKScene,
        viewport: CGRect,
        frameTime: TimeInterval,
        pixelFormat: MTLPixelFormat,
        isOpaque opaque: Bool
    ) {
        renderer = nil
        device = nil
        self.scene = scene
        dimensions = MTITextureDimensions(cgSize: viewport.size)
        alphaType = opaque ? .alphaIsOne : .premultiplied
        self.pixelFormat = pixelFormat
        self.frameTime = frameTime
        self.viewport = viewport
    }

    func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        let renderer: SKRenderer
        if let device, let existingRenderer = self.renderer {
            guard renderingContext.context.device === device else {
                throw MTIError(code: .crossDeviceRendering, message: "MTIErrorCrossDeviceRendering")
            }
            renderer = existingRenderer
        } else if let scene {
            renderer = SKRenderer(device: renderingContext.context.device)
            renderer.scene = scene
        } else {
            fatalError("No render content found.")
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
        guard let targetTexture = renderTarget.texture else {
            throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
        }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = targetTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        let depthStencilTextureDescriptor = MTLTextureDescriptor()
        depthStencilTextureDescriptor.width = targetTexture.width
        depthStencilTextureDescriptor.height = targetTexture.height
        depthStencilTextureDescriptor.depth = 1
        depthStencilTextureDescriptor.pixelFormat = .depth32Float_stencil8
        depthStencilTextureDescriptor.usage = .renderTarget
        if renderingContext.context.isMemorylessTextureSupported, #available(
            macOS 11.0,
            macCatalyst 14.0,
            iOS 10.0,
            tvOS 10.0,
            *
        ) {
            depthStencilTextureDescriptor.storageMode = .memoryless
        } else {
            depthStencilTextureDescriptor.storageMode = .private
        }
        guard let depthStencilTexture = renderingContext.context.device
            .makeTexture(descriptor: depthStencilTextureDescriptor)
        else {
            throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
        }
        // Depth render target
        renderPassDescriptor.depthAttachment.texture = depthStencilTexture
        renderPassDescriptor.depthAttachment.loadAction = .dontCare
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        // Stencil render target
        renderPassDescriptor.stencilAttachment.texture = depthStencilTexture
        renderPassDescriptor.stencilAttachment.loadAction = .dontCare
        renderPassDescriptor.stencilAttachment.storeAction = .dontCare
        renderer.update(atTime: frameTime)
        renderer.render(
            withViewport: viewport,
            commandBuffer: renderingContext.commandBuffer,
            renderPassDescriptor: renderPassDescriptor
        )
        return renderTarget
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        // The Obj-C original always put `renderer` in the dictionary, which raises when the promise
        // was built from a scene rather than a renderer.
        var content: [String: Any] = ["frameTime": frameTime]
        if let renderer {
            content["SKRenderer"] = renderer
        }
        return MTIImagePromiseDebugInfo(promise: self, type: .source, content: content)
    }
}

public final class MTISKSceneRenderer {
    private let renderer: SKRenderer
    private let device: MTLDevice

    public init(device: MTLDevice) {
        renderer = SKRenderer(device: device)
        self.device = device
    }

    public var scene: SKScene? {
        get { renderer.scene }
        set { renderer.scene = newValue }
    }

    public var skRenderer: SKRenderer {
        renderer
    }

    /// Create a `MTImage` for the scene at the specified time. The image can only be render with the
    /// MTIContext that shares the same metal device with this renderer.
    public func snapshot(
        atTime time: TimeInterval,
        viewport: CGRect,
        pixelFormat: MTLPixelFormat,
        isOpaque: Bool
    ) -> MTIImage {
        let promise = MTISKSceneImagePromise(
            renderer: renderer,
            device: device,
            viewport: viewport,
            frameTime: time,
            pixelFormat: pixelFormat,
            isOpaque: isOpaque
        )
        return MTIImage(promise: promise)
    }
}

public extension MTIImage {
    /// Create a `MTIImage` object from a static `SKScene`. The scene will be copied. If you want to
    /// update the scene, use `MTISKSceneRenderer`.
    convenience init(
        skScene scene: SKScene,
        time: TimeInterval,
        viewport: CGRect,
        pixelFormat: MTLPixelFormat,
        isOpaque: Bool
    ) {
        let promise = MTISKSceneImagePromise(
            scene: scene.copy() as! SKScene,
            viewport: viewport,
            frameTime: time,
            pixelFormat: pixelFormat,
            isOpaque: isOpaque
        )
        self.init(promise: promise, cachePolicy: .persistent)
    }

    convenience init(skScene scene: SKScene) {
        self.init(skScene: scene,
                  time: CFAbsoluteTimeGetCurrent(),
                  viewport: CGRect(x: 0, y: 0, width: scene.size.width, height: scene.size.height),
                  pixelFormat: .invalid,
                  isOpaque: false)
    }
}

#endif
