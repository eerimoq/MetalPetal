//
//  MTIImageView.swift
//  Pods
//
//  Created by Yu Ao on 09/10/2017.
//

#if canImport(UIKit)

import Foundation
import Metal
import MetalKit
import UIKit

public final class MTIImageView: UIView, MTKViewDelegate {
    public var automaticallyCreatesContext: Bool = true

    public var colorPixelFormat: MTLPixelFormat {
        get {
            renderView.colorPixelFormat
        }
        set {
            let oldColorPixelFormat = renderView.colorPixelFormat
            renderView.colorPixelFormat = newValue
            if oldColorPixelFormat != newValue {
                setNeedsRedraw()
            }
        }
    }

    public var clearColor: MTLClearColor {
        get {
            renderView.clearColor
        }
        set {
            let oldClearColor = renderView.clearColor
            renderView.clearColor = newValue
            if oldClearColor.red != newValue.red ||
                oldClearColor.green != newValue.green ||
                oldClearColor.blue != newValue.blue ||
                oldClearColor.alpha != newValue.alpha
            {
                setNeedsRedraw()
            }
        }
    }

    public var resizingMode: MTIDrawableRenderingResizingMode = .aspect

    /// The `MTIContext` used to render the image. If no context is assigned and
    /// `automaticallyCreatesContext` is set to `true` (the default value), a `MTIContext` is created
    /// automatically when the image view renders its content.
    public var context: MTIContext? {
        get {
            setupContextIfNeeded()
            return _context
        }
        set {
            _context = newValue
            renderView.device = newValue?.device
        }
    }

    private var _context: MTIContext?

    public var image: MTIImage? {
        get {
            _image
        }
        set {
            assert(Thread.isMainThread, "-[MTIImageView setImage:] can only be called on main thread.")
            if _image !== newValue {
                _image = newValue
                updateContentScaleFactor()
                setNeedsRedraw()
            }
        }
    }

    private var _image: MTIImage?

    @available(
        *,
        deprecated,
        message: """
        Set `drawsImmediately` to `YES` is not recommended anymore. Please \
        file an issue describing how you'd like to use this feature. \
        https://github.com/MetalPetal/MetalPetal
        """
    )
    public var drawsImmediately: Bool {
        get {
            _drawsImmediately
        }
        set {
            _drawsImmediately = newValue
            if newValue {
                renderView.isPaused = true
                renderView.enableSetNeedsDisplay = false
            } else {
                renderView.isPaused = true
                renderView.enableSetNeedsDisplay = true
            }
        }
    }

    private var _drawsImmediately = false

    private var renderView: MTKView!

    private var screenScale: CGFloat = 1.0

    private var contextCreationError: Error?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupImageView()
    }

    private func setupImageView() {
        accessibilityIgnoresInvertColors = true

        resizingMode = .aspect
        automaticallyCreatesContext = true

        let renderView = MTKView(frame: bounds, device: nil)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        renderView.delegate = self
        renderView.isPaused = true
        renderView.enableSetNeedsDisplay = true
        renderView.contentMode = contentMode
        addSubview(renderView)
        self.renderView = renderView
        _drawsImmediately = false

        isOpaque = true
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if let screen = window?.screen {
            screenScale = min(screen.nativeScale, screen.scale)
        } else {
            screenScale = 1.0
        }
    }

    private func setupContextIfNeeded() {
        if _context == nil, contextCreationError == nil, automaticallyCreatesContext {
            do {
                _context = try MTIContext(device: MTLCreateSystemDefaultDevice()!)
            } catch {
                contextCreationError = error
            }
            renderView.device = _context?.device
        }
    }

    override public var contentMode: UIView.ContentMode {
        didSet {
            renderView?.contentMode = contentMode
        }
    }

    override public var isOpaque: Bool {
        didSet {
            renderView?.isOpaque = isOpaque
            renderView?.layer.isOpaque = isOpaque
            if oldValue != isOpaque {
                setNeedsRedraw()
            }
        }
    }

    override public var isHidden: Bool {
        didSet {
            if oldValue {
                setNeedsRedraw()
            }
        }
    }

    override public var alpha: CGFloat {
        didSet {
            if oldValue <= 0 {
                setNeedsRedraw()
            }
        }
    }

    private func updateContentScaleFactor() {
        guard let renderView, let image = _image else { return }
        if renderView.frame.size.width > 0, renderView.frame.size.height > 0, image.size.width > 0,
           image.size.height > 0, window?.screen != nil
        {
            let imageSize = image.size
            let widthScale = imageSize.width / renderView.bounds.size.width
            let heightScale = imageSize.height / renderView.bounds.size.height
            let nativeScale = screenScale
            let scale = max(min(max(widthScale, heightScale), nativeScale), 1.0)
            if abs(renderView.contentScaleFactor - scale) > 0.00001 {
                renderView.contentScaleFactor = scale
            }
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        updateContentScaleFactor()
        setNeedsRedraw()
    }

    private func setNeedsRedraw() {
        guard let renderView else { return }
        if _drawsImmediately {
            renderView.draw()
        } else {
            renderView.setNeedsDisplay()
        }
    }

    public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    public func draw(in view: MTKView) {
        autoreleasepool {
            if !isHidden, alpha > 0 {
                setupContextIfNeeded()

                guard let context = _context else {
                    return
                }
                if let imageToRender = _image {
                    let request = MTIDrawableRenderingRequest(
                        drawableProvider: view,
                        resizingMode: resizingMode
                    )
                    do {
                        try context.render(imageToRender, toDrawableWithRequest: request)
                    } catch {
                        #if DEBUG
                        if ProcessInfo.processInfo.environment["MTI_PRINT_ENABLED"] != nil {
                            NSLog("%@: Failed to render image %@ - %@", self, imageToRender, error as NSError)
                        }
                        #endif
                    }
                } else {
                    // Clear current drawable.
                    if let renderPassDescriptor = view.currentRenderPassDescriptor,
                       let drawable = view.currentDrawable
                    {
                        let commandBuffer = context.commandQueue.makeCommandBuffer()
                        let commandEncoder = commandBuffer?
                            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)
                        commandEncoder?.endEncoding()
                        commandBuffer?.present(drawable)
                        commandBuffer?.commit()
                    }
                }
            }
        }
    }
}

#endif
