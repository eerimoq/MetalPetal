//
//  MTIImage.swift
//  MetalPetal
//
//  Created by YuAo on 25/06/2017.
//

import CoreImage
import CoreVideo
import Foundation
import Metal
import MetalKit
import ModelIO

private func MTIPreferredAlphaType(forCVPixelBuffer pixelBuffer: CVPixelBuffer) -> MTIAlphaType {
    var alphaType = MTIAlphaType.unknown
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
    if pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || pixelFormat ==
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    {
        alphaType = .alphaIsOne
    }
    assert(
        alphaType != .unknown,
        "Cannot predicate alpha type. Please call the init method with the alphaType parameter."
    )
    if alphaType == .unknown {
        // We assume the alpha type to be non-premultiplied.
        alphaType = .nonPremultiplied
    }
    return alphaType
}

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
        assertionFailure("Unknown alphaInfo.")
    }
    return alphaType
}

private func MTIPreferredAlphaType(forCGImage cgImage: CGImage) -> MTIAlphaType {
    MTIPreferredAlphaType(forImageWith: MTIImageProperties(cgImage: cgImage))
}

/// A representation of an image to be processed or produced.
public final class MTIImage: NSObject, NSCopying {
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
        self.promise = promise.copy(with: nil) as! MTIImagePromise
        dimensions = promise.dimensions
        self.samplerDescriptor = samplerDescriptor.copy() as! MTISamplerDescriptor
        self.cachePolicy = cachePolicy
        alphaType = promise.alphaType
        super.init()
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
        if samplerDescriptor.isEqual(self.samplerDescriptor) {
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

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    // `promise` is a Swift protocol type and cannot be an `@objc` property, but it was KVC-accessible
    // when `MTIImage` was an Objective-C class. Expose it via KVC so key paths like `promise.…` keep
    // working (e.g. for tooling that inspects the render graph).
    override public func value(forKey key: String) -> Any? {
        if key == "promise" {
            return promise
        }
        return super.value(forKey: key)
    }

    override public var description: String {
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
        let pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        if pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
            pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
            pixelFormatType == kCVPixelFormatType_OneComponent8 ||
            pixelFormatType == kCVPixelFormatType_OneComponent16Half ||
            pixelFormatType == kCVPixelFormatType_OneComponent32Float
        {
            assert(
                alphaType == .alphaIsOne,
                "Alpha type should be `.alphaIsOne` for `CVPixelBuffer`s without a alpha channel."
            )
        }
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
                                                         planeIndex: UInt(planeIndex),
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
            promise: MTIBitmapDataImagePromise(bitmapData: data, width: UInt(width), height: UInt(height),
                                               bytesPerRow: UInt(bytesPerRow), pixelFormat: pixelFormat,
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
}
