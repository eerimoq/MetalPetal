//
//  MTIImage.swift
//  MetalPetal
//
//  Created by YuAo on 25/06/2017.
//

import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import Metal
import MetalKit
import ModelIO

private func MTIPreferredAlphaType(forImageWith properties: MTIImageProperties) -> MTIAlphaType {
    let alphaInfo = properties.alphaInfo
    var alphaType = MTIAlphaType.alphaIsOne
    switch alphaInfo {
    case .none, .noneSkipLast, .noneSkipFirst:
        alphaType = .alphaIsOne
    case .alphaOnly, .last, .first:
        alphaType = .nonPremultiplied
    case .premultipliedLast, .premultipliedFirst:
        alphaType = .premultiplied
    @unknown default:
        break
    }
    return alphaType
}

private func MTIPreferredAlphaType(forCGImage cgImage: CGImage) -> MTIAlphaType {
    MTIPreferredAlphaType(forImageWith: MTIImageProperties(cgImage: cgImage))
}

/// A representation of an image to be processed or produced.
public final class MTIImage: Hashable, CustomStringConvertible {
    public enum CachePolicy: Int {
        case transient
        case persistent
    }

    public let promise: MTIImagePromise
    public let cachePolicy: CachePolicy
    public let samplerDescriptor: MTISamplerDescriptor
    public let alphaType: MTIAlphaType
    public let dimensions: MTITextureDimensions

    public init(promise: MTIImagePromise, samplerDescriptor: MTISamplerDescriptor, cachePolicy: CachePolicy) {
        self.promise = promise
        dimensions = promise.dimensions
        self.samplerDescriptor = samplerDescriptor
        self.cachePolicy = cachePolicy
        alphaType = promise.alphaType
    }

    public convenience init(promise: MTIImagePromise) {
        self.init(promise: promise, samplerDescriptor: MTISamplerDescriptor.default, cachePolicy: .transient)
    }

    public convenience init(promise: MTIImagePromise, samplerDescriptor: MTISamplerDescriptor) {
        self.init(promise: promise, samplerDescriptor: samplerDescriptor, cachePolicy: .transient)
    }

    public convenience init(promise: MTIImagePromise, cachePolicy: CachePolicy) {
        self.init(promise: promise, samplerDescriptor: MTISamplerDescriptor.default, cachePolicy: cachePolicy)
    }

    public func withSamplerDescriptor(_ samplerDescriptor: MTISamplerDescriptor) -> MTIImage {
        if samplerDescriptor == self.samplerDescriptor {
            return self
        }
        return MTIImage(promise: promise, samplerDescriptor: samplerDescriptor, cachePolicy: cachePolicy)
    }

    public func withCachePolicy(_ cachePolicy: CachePolicy) -> MTIImage {
        if cachePolicy == self.cachePolicy {
            return self
        }
        return MTIImage(promise: promise, samplerDescriptor: samplerDescriptor, cachePolicy: cachePolicy)
    }

    // Identity semantics, matching the pointer-based `isEqual:`/`hash` MTIImage inherited from NSObject.
    // The render graph relies on this.
    public static func == (lhs: MTIImage, rhs: MTIImage) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public var description: String {
        """
        <\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque()); \
        width = \(dimensions.width); \
        height = \(dimensions.height); \
        depth = \(dimensions.depth); \
        cachePolicy = \(cachePolicy.rawValue); \
        promise = \(promise)>
        """
    }

    public var extent: CGRect {
        CGRect(x: 0, y: 0, width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
    }

    public var size: CGSize {
        CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
    }

    /// A 1x1 white image
    public static let white = MTIImage(
        color: MTIColor(red: 1, green: 1, blue: 1, alpha: 1),
        sRGB: false,
        size: CGSize(width: 1, height: 1)
    )

    /// A 1x1 black image
    public static let black = MTIImage(
        color: MTIColor(red: 0, green: 0, blue: 0, alpha: 1),
        sRGB: false,
        size: CGSize(width: 1, height: 1)
    )

    /// A 1x1 transparent image
    public static let transparent = MTIImage(
        color: MTIColor(red: 0, green: 0, blue: 0, alpha: 0),
        sRGB: false,
        size: CGSize(width: 1, height: 1)
    )
}

public extension MTIImage {
    convenience init(cvPixelBuffer pixelBuffer: CVPixelBuffer, alphaType: MTIAlphaType) {
        self.init(
            promise: MTICVPixelBufferPromise(cvPixelBuffer: pixelBuffer,
                                             options: MTICVPixelBufferRenderingOptions.default,
                                             alphaType: alphaType),
            cachePolicy: .persistent
        )
    }

    convenience init(
        cvPixelBuffer pixelBuffer: CVPixelBuffer,
        renderingAPI: MTICVPixelBufferRenderingAPI,
        alphaType: MTIAlphaType
    ) {
        let options = MTICVPixelBufferRenderingOptions(renderingAPI: renderingAPI, sRGB: false)
        self.init(
            promise: MTICVPixelBufferPromise(cvPixelBuffer: pixelBuffer, options: options,
                                             alphaType: alphaType),
            cachePolicy: .persistent
        )
    }

    convenience init(
        cvPixelBuffer pixelBuffer: CVPixelBuffer,
        options: MTICVPixelBufferRenderingOptions,
        alphaType: MTIAlphaType
    ) {
        self.init(
            promise: MTICVPixelBufferPromise(cvPixelBuffer: pixelBuffer, options: options,
                                             alphaType: alphaType),
            cachePolicy: .persistent
        )
    }

    convenience init(
        cvPixelBuffer pixelBuffer: CVPixelBuffer,
        planeIndex: Int,
        textureDescriptor: MTLTextureDescriptor,
        alphaType: MTIAlphaType
    ) {
        self.init(
            promise: MTICVPixelBufferDirectBridgePromise(cvPixelBuffer: pixelBuffer,
                                                         planeIndex: Int(planeIndex),
                                                         textureDescriptor: textureDescriptor,
                                                         alphaType: alphaType),
            cachePolicy: .persistent
        )
    }

    convenience init(cgImage: CGImage, options: [MTKTextureLoader.Option: Any]?, isOpaque: Bool = false) {
        let preferredAlphaType: MTIAlphaType = isOpaque ? .alphaIsOne :
            MTIPreferredAlphaType(forCGImage: cgImage)
        self.init(
            promise: MTILegacyCGImagePromise(cgImage: cgImage, options: options,
                                             alphaType: preferredAlphaType),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation = .up,
        options: MTICGImageLoadingOptions = .default,
        isOpaque: Bool = false
    ) {
        self.init(
            promise: MTICGImagePromise(cgImage: cgImage, orientation: orientation, options: options,
                                       isOpaque: isOpaque),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init(texture: MTLTexture, alphaType: MTIAlphaType) {
        self.init(
            promise: MTITexturePromise(texture: texture, alphaType: alphaType),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init(ciImage: CIImage, isOpaque: Bool = false) {
        self.init(
            promise: MTICIImagePromise(ciImage: ciImage, bounds: ciImage.extent, isOpaque: isOpaque,
                                       options: MTICIImageRenderingOptions.default),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init(ciImage: CIImage, isOpaque: Bool, options: MTICIImageRenderingOptions) {
        self.init(
            promise: MTICIImagePromise(ciImage: ciImage, bounds: ciImage.extent, isOpaque: isOpaque,
                                       options: options),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init(ciImage: CIImage, bounds: CGRect, isOpaque: Bool, options: MTICIImageRenderingOptions) {
        self.init(
            promise: MTICIImagePromise(ciImage: ciImage, bounds: bounds, isOpaque: isOpaque,
                                       options: options),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init?(
        contentsOf url: URL,
        options: [MTKTextureLoader.Option: Any]?,
        alphaType: MTIAlphaType? = nil
    ) {
        guard let properties = MTIImageProperties(imageAt: url) else {
            return nil
        }
        let dimensions = MTITextureDimensions(
            width: properties.displayWidth,
            height: properties.displayHeight,
            depth: 1
        )
        let preferredAlphaType = alphaType ?? MTIPreferredAlphaType(forImageWith: properties)
        guard let urlPromise = MTIImageURLPromise(
            contentsOf: url,
            dimensions: dimensions,
            options: options,
            alphaType: preferredAlphaType
        ) else {
            return nil
        }
        self.init(
            promise: urlPromise,
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init?(
        contentsOf url: URL,
        size: CGSize,
        options: [MTKTextureLoader.Option: Any]?,
        alphaType: MTIAlphaType
    ) {
        let dimensions = MTITextureDimensions(width: Int(size.width), height: Int(size.height), depth: 1)
        guard let urlPromise = MTIImageURLPromise(
            contentsOf: url,
            dimensions: dimensions,
            options: options,
            alphaType: alphaType
        ) else {
            return nil
        }
        self.init(
            promise: urlPromise,
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init?(
        contentsOf url: URL,
        options: MTICGImageLoadingOptions = .default,
        isOpaque: Bool = false
    ) {
        guard let properties = MTIImageProperties(imageAt: url) else {
            return nil
        }
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(imageSource) > 0
        else {
            return nil
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        self.init(
            promise: MTICGImagePromise(cgImage: cgImage, orientation: properties.orientation,
                                       options: options,
                                       isOpaque: isOpaque),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init(color: MTIColor, sRGB: Bool, size: CGSize) {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        self.init(
            promise: MTIColorImagePromise(color: color, sRGB: sRGB, size: size),
            samplerDescriptor: samplerDescriptor.makeMTISamplerDescriptor(),
            cachePolicy: .persistent
        )
    }

    convenience init(
        bitmapData data: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixelFormat: MTLPixelFormat,
        alphaType: MTIAlphaType
    ) {
        self.init(
            promise: MTIBitmapDataImagePromise(bitmapData: data, width: Int(width), height: Int(height),
                                               bytesPerRow: Int(bytesPerRow), pixelFormat: pixelFormat,
                                               alphaType: alphaType),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init(
        named name: String,
        in bundle: Bundle?,
        size: CGSize,
        scaleFactor: CGFloat,
        options: [MTKTextureLoader.Option: Any]?,
        alphaType: MTIAlphaType
    ) {
        self.init(
            promise: MTINamedImagePromise(name: name, bundle: bundle, size: size, scaleFactor: scaleFactor,
                                          options: options, alphaType: alphaType),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    convenience init(
        mdlTexture texture: MDLTexture,
        options: [MTKTextureLoader.Option: Any]?,
        alphaType: MTIAlphaType
    ) {
        self.init(
            promise: MTIMDLTexturePromise(mdlTexture: texture, options: options, alphaType: alphaType),
            samplerDescriptor: MTISamplerDescriptor.default,
            cachePolicy: .persistent
        )
    }

    func adjusting(saturation: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTISaturationFilter()
        filter.saturation = saturation
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    func adjusting(exposure: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTIExposureFilter()
        filter.exposure = exposure
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    func adjusting(brightness: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTIBrightnessFilter()
        filter.brightness = brightness
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    func adjusting(contrast: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTIContrastFilter()
        filter.contrast = contrast
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    func adjusting(vibrance: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTIVibranceFilter()
        filter.amount = vibrance
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    /// Returns a MTIImage object that specifies a subimage of the image. If the `region` parameter defines an
    /// empty area, returns nil.
    func cropped(to region: MTICropRegion, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage? {
        let filter = MTICropFilter()
        filter.cropRegion = region
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage
    }

    /// Returns a MTIImage object that specifies a subimage of the image. If the `rect` parameter defines an
    /// empty area, returns nil.
    func cropped(to rect: CGRect, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage? {
        let filter = MTICropFilter()
        filter.cropRegion = MTICropRegion(bounds: rect, unit: .pixel)
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage
    }

    /// Returns a MTIImage object that is resized to a specified size. If the `size` parameter has
    /// zero/negative width or height, returns nil.
    func resized(to size: CGSize, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage? {
        guard size.width >= 1, size.height >= 1 else {
            return nil
        }
        return MTIUnaryImageRenderingFilter.image(
            byProcessingImage: self,
            orientation: .up,
            parameters: [:],
            outputPixelFormat: outputPixelFormat,
            outputImageSize: size
        )
    }

    /// Returns a MTIImage object that is resized to a specified size. If the `size` parameter has
    /// zero/negative width or height, returns nil.
    func resized(
        to target: CGSize,
        resizingMode: MTIDrawableRenderingResizingMode,
        outputPixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage? {
        let size: CGSize = switch resizingMode {
        case .aspect:
            MTIMakeRect(aspectRatio: self.size, insideRect: CGRect(origin: .zero, size: target)).size
        case .aspectFill:
            MTIMakeRect(aspectRatio: self.size, fillRect: CGRect(origin: .zero, size: target)).size
        case .scale:
            target
        }
        guard size.width >= 1, size.height >= 1 else {
            return nil
        }
        return MTIUnaryImageRenderingFilter.image(
            byProcessingImage: self,
            orientation: .up,
            parameters: [:],
            outputPixelFormat: outputPixelFormat,
            outputImageSize: size
        )
    }
}

#if canImport(UIKit)

import UIKit

fileprivate extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        @unknown default:
            fatalError("Unknown UIImage.Orientation: \(rawValue)")
        }
    }
}

public extension MTIImage {
    convenience init(image: UIImage, colorSpace: CGColorSpace? = nil, isOpaque: Bool = false) {
        let cgImage: CGImage
        let orientation: CGImagePropertyOrientation
        if let cg = image.cgImage {
            cgImage = cg
            orientation = image.imageOrientation.cgImagePropertyOrientation
        } else {
            let format = UIGraphicsImageRendererFormat.preferred()
            format.opaque = isOpaque
            format.scale = image.scale
            cgImage = UIGraphicsImageRenderer(size: image.size).image { _ in
                image.draw(at: .zero)
            }.cgImage!
            orientation = .up
        }
        let options = MTICGImageLoadingOptions(colorSpace: colorSpace)
        self.init(cgImage: cgImage, orientation: orientation, options: options, isOpaque: isOpaque)
    }
}

#endif

#if canImport(AppKit)

import AppKit

public extension MTIImage {
    @available(macCatalyst, unavailable)
    convenience init?(image: NSImage, colorSpace: CGColorSpace? = nil, isOpaque: Bool = false) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let options = MTICGImageLoadingOptions(colorSpace: colorSpace)
        self.init(cgImage: cgImage, orientation: .up, options: options, isOpaque: isOpaque)
    }
}

#endif
