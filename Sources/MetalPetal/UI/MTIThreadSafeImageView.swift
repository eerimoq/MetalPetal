//
//  MTIThreadSafeImageView.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/6/12.
//

#if canImport(UIKit)

import Foundation
import Metal
import os
import QuartzCore
import UIKit

public let MTIImageViewErrorDomain = "MTIImageViewErrorDomain"

public enum MTIImageViewError: Int {
    case contextNotFound = 1001
    case sameImage = 1002
}

private protocol MTICAMetalLayer: AnyObject {
    var device: MTLDevice? { get set }
    var pixelFormat: MTLPixelFormat { get set }
    var drawableSize: CGSize { get set }
    var isOpaque: Bool { get set }
    var contentsScale: CGFloat { get set }
    var colorspace: CGColorSpace? { get set }
    func nextDrawable() -> CAMetalDrawable?
}

// For simulator < iOS 13
private final class MTIStubMetalLayer: CALayer, MTICAMetalLayer {
    var device: MTLDevice?
    var pixelFormat: MTLPixelFormat = .bgra8Unorm
    var drawableSize: CGSize = .zero

    // CALayer already has `contentsScale` and `isOpaque`.

    func nextDrawable() -> CAMetalDrawable? {
        nil
    }

    var colorspace: CGColorSpace? {
        get { nil }
        set {}
    }
}

// `CAMetalLayer` is annotated iOS 13+ on the simulator SDK (Metal-on-simulator was gated there),
// which is why the `MTIStubMetalLayer` fallback exists for older simulators. The conformance is
// reached dynamically (`layer as! MTICAMetalLayer`), so gating it here does not affect the runtime
// cast on devices, where `CAMetalLayer` has been available since iOS 8.
@available(iOS 13.0, *)
extension CAMetalLayer: MTICAMetalLayer {}

/// An image view that immediately draws its `image` on the calling thread. Most of the custom
/// properties can be accessed from any thread safely. It's recommended to use the `MTIImageView`
/// which draws it's content on the main thread instead of this view.
public final class MTIThreadSafeImageView: UIView, MTIDrawableProvider {
    override public static var layerClass: AnyClass {
        #if targetEnvironment(simulator)
        if #available(iOS 13.0, *) {
            return CAMetalLayer.self
        } else {
            return MTIStubMetalLayer.self
        }
        #else
        return CAMetalLayer.self
        #endif
    }

    private var renderLayer: MTICAMetalLayer {
        layer as! MTICAMetalLayer
    }

    public var automaticallyCreatesContext: Bool = true

    private let lock = OSAllocatedUnfairLock()

    private var screenScale: CGFloat = 1.0

    private var currentDrawable: CAMetalDrawable?

    private var backgroundAccessingBounds: CGRect = .zero

    private var currentDrawableValid: Bool = false

    private var currentDrawableSize: CGSize = .zero

    private var contextCreationError: Error?

    private var _context: MTIContext?
    private var _image: MTIImage?
    private var _clearColor: MTLClearColor = MTLClearColorMake(0, 0, 0, 0)
    private var _resizingMode: MTIDrawableRenderingResizingMode = .aspect

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupImageView()
    }

    private func setupImageView() {
        _resizingMode = .aspect
        automaticallyCreatesContext = true
        renderLayer.device = nil
        currentDrawableSize = renderLayer.drawableSize
        isOpaque = true
    }

    override public var isOpaque: Bool {
        get {
            super.isOpaque
        }
        set {
            lock.lock()
            let oldOpaque = super.isOpaque
            super.isOpaque = newValue
            renderLayer.isOpaque = newValue
            if oldOpaque != newValue {
                renderImage(_image, completion: nil)
            }
            lock.unlock()
        }
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        lock.lock()
        if let screen = window?.screen {
            screenScale = min(screen.nativeScale, screen.scale)
        } else {
            screenScale = 1.0
        }
        lock.unlock()
    }

    public var context: MTIContext? {
        get {
            lock.lock()
            setupContextIfNeeded()
            let c = _context
            lock.unlock()
            return c
        }
        set {
            lock.lock()
            _context = newValue
            renderLayer.device = newValue?.device
            lock.unlock()
        }
    }

    private func setupContextIfNeeded() {
        if _context == nil, contextCreationError == nil, automaticallyCreatesContext {
            do {
                _context = try MTIContext(device: MTLCreateSystemDefaultDevice()!)
            } catch {
                contextCreationError = error
            }
            renderLayer.device = _context?.device
        }
    }

    public var colorPixelFormat: MTLPixelFormat {
        get {
            lock.lock()
            let format = renderLayer.pixelFormat
            lock.unlock()
            return format
        }
        set {
            lock.lock()
            if renderLayer.pixelFormat != newValue {
                renderLayer.pixelFormat = newValue
                renderImage(_image, completion: nil)
            }
            lock.unlock()
        }
    }

    public var colorSpace: CGColorSpace? {
        get {
            lock.lock()
            let colorspace = renderLayer.colorspace
            lock.unlock()
            return colorspace
        }
        set {
            lock.lock()
            if renderLayer.colorspace !== newValue {
                renderLayer.colorspace = newValue
                renderImage(_image, completion: nil)
            }
            lock.unlock()
        }
    }

    public var clearColor: MTLClearColor {
        get {
            lock.lock()
            let color = _clearColor
            lock.unlock()
            return color
        }
        set {
            lock.lock()
            if _clearColor.red != newValue.red ||
                _clearColor.green != newValue.green ||
                _clearColor.blue != newValue.blue ||
                _clearColor.alpha != newValue.alpha
            {
                _clearColor = newValue
                renderImage(_image, completion: nil)
            }
            lock.unlock()
        }
    }

    public var image: MTIImage? {
        get {
            lock.lock()
            let image = _image
            lock.unlock()
            return image
        }
        set {
            setImage(newValue, renderCompletion: nil)
        }
    }

    /// Update the image. `renderCompletion` will be called when the rendering is finished or failed.
    /// The callback will be called on current thread or a metal internal thread.
    public func setImage(_ image: MTIImage?, renderCompletion: ((Error?) -> Void)?) {
        var renderedImage = false

        lock.lock()
        if _image !== image {
            _image = image
            renderedImage = true
            renderImage(image, completion: renderCompletion)
        }
        lock.unlock()

        if !renderedImage {
            renderCompletion?(NSError(
                domain: MTIImageViewErrorDomain,
                code: MTIImageViewError.sameImage.rawValue,
                userInfo: nil
            ))
        }
    }

    public var resizingMode: MTIDrawableRenderingResizingMode {
        get {
            lock.lock()
            let resizingMode = _resizingMode
            lock.unlock()
            return resizingMode
        }
        set {
            lock.lock()
            if _resizingMode != newValue {
                _resizingMode = newValue
                renderImage(_image, completion: nil)
            }
            lock.unlock()
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        lock.lock()
        if !backgroundAccessingBounds.equalTo(bounds) {
            backgroundAccessingBounds = bounds
            renderImage(_image, completion: nil)
        }
        lock.unlock()
    }

    // locking access

    private func renderImage(_ image: MTIImage?, completion: ((Error?) -> Void)?) {
        setupContextIfNeeded()

        guard let context = _context else {
            completion?(contextCreationError ?? NSError(
                domain: MTIImageViewErrorDomain,
                code: MTIImageViewError.contextNotFound.rawValue,
                userInfo: nil
            ))
            return
        }

        updateContentScaleFactor()

        let resizingMode = _resizingMode
        // and acquire _clearColor

        invalidateCurrentDrawable()

        let request = MTIDrawableRenderingRequest(drawableProvider: self, resizingMode: resizingMode)

        if let imageToRender = image {
            do {
                _ = try context.startTask(toRender: imageToRender, toDrawableWithRequest: request) { task in
                    completion?(task.error)
                }
            } catch {
                #if DEBUG
                if ProcessInfo.processInfo.environment["MTI_PRINT_ENABLED"] != nil {
                    NSLog(
                        "%@: Failed to render image %@ - %@",
                        self,
                        String(describing: imageToRender),
                        error as NSError
                    )
                }
                #endif
                completion?(error)
            }
        } else {
            // Clear current drawable.
            if let renderPassDescriptor = renderPassDescriptor(for: request),
               let drawable = drawable(for: request)
            {
                let commandBuffer = context.commandQueue.makeCommandBuffer()
                let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
                commandEncoder?.endEncoding()
                commandBuffer?.present(drawable)
                commandBuffer?.addCompletedHandler { cb in
                    completion?(cb.error)
                }
                commandBuffer?.commit()
            } else {
                completion?(MTIError(code: .emptyDrawable, message: "MTIErrorEmptyDrawable"))
            }
        }
    }

    private func updateContentScaleFactor() {
        let renderLayer = renderLayer
        if backgroundAccessingBounds.size.width > 0, backgroundAccessingBounds.size.height > 0,
           let image = _image, image.size.width > 0, image.size.height > 0
        {
            let imageSize = image.size
            let widthScale = imageSize.width / backgroundAccessingBounds.size.width
            let heightScale = imageSize.height / backgroundAccessingBounds.size.height
            let nativeScale = screenScale
            let scale = max(min(max(widthScale, heightScale), nativeScale), 1.0)
            let drawableSize = CGSize(
                width: backgroundAccessingBounds.size.width * scale,
                height: backgroundAccessingBounds.size.height * scale
            )
            if abs(renderLayer.contentsScale - scale) > 0.00001 || !drawableSize
                .equalTo(currentDrawableSize)
            {
                renderLayer.contentsScale = scale
                renderLayer.drawableSize = drawableSize
                currentDrawableSize = drawableSize
            }
        }
    }

    private func invalidateCurrentDrawable() {
        currentDrawableValid = false
    }

    private func requestNextDrawableIfNeeded() {
        if !currentDrawableValid {
            currentDrawable = renderLayer.nextDrawable()
            currentDrawableValid = true
        }
    }

    public func drawable(for _: MTIDrawableRenderingRequest) -> MTLDrawable? {
        requestNextDrawableIfNeeded()
        return currentDrawable
    }

    public func renderPassDescriptor(for _: MTIDrawableRenderingRequest) -> MTLRenderPassDescriptor? {
        requestNextDrawableIfNeeded()
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = currentDrawable?.texture
        descriptor.colorAttachments[0].clearColor = _clearColor
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }
}

#endif
