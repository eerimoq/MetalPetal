//
//  MTITextureLoader.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/1/10.
//

import CoreImage
import CoreVideo
import Foundation
import Metal
// MetalKit is part of MetalPetal's public API (e.g. `MTKTextureLoader.Option`), and the Objective-C
// umbrella used to re-export it. Preserve that so consumers importing MetalPetal keep seeing MetalKit.
@_exported import MetalKit

/// Abstract interface for texture loaders.
public protocol MTITextureLoader: AnyObject {
    static func makeTextureLoader(device: MTLDevice) -> MTITextureLoader

    func newTexture(with cgImage: CGImage, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture

    func newTexture(withContentsOf url: URL, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture

    func newTexture(
        withName name: String,
        scaleFactor: CGFloat,
        bundle: Bundle?,
        options: [MTKTextureLoader.Option: Any]?
    ) throws -> MTLTexture

    func newTexture(with mdlTexture: MDLTexture, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture
}

extension MTKTextureLoader: MTITextureLoader {
    public static func makeTextureLoader(device: MTLDevice) -> MTITextureLoader {
        MTKTextureLoader(device: device)
    }

    public func newTexture(with cgImage: CGImage, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture {
        try newTexture(cgImage: cgImage, options: options)
    }

    public func newTexture(withContentsOf url: URL, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture {
        try newTexture(URL: url, options: options)
    }

    public func newTexture(
        withName name: String,
        scaleFactor: CGFloat,
        bundle: Bundle?,
        options: [MTKTextureLoader.Option: Any]?
    ) throws -> MTLTexture {
        try newTexture(name: name, scaleFactor: scaleFactor, bundle: bundle, options: options)
    }

    public func newTexture(with mdlTexture: MDLTexture, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture {
        try newTexture(texture: mdlTexture, options: options)
    }
}

/// The default texture loader. A `MTIDefaultTextureLoader` object uses a `MTKTextureLoader` internally to load
/// textures. When an image cannot be loaded with `MTKTextureLoader`, `MTIDefaultTextureLoader` draws the image
/// to a 32bits/pixel BGRA `CVPixelBuffer` and creates a texture from that pixel buffer.
public final class MTIDefaultTextureLoader: NSObject, MTITextureLoader {
    private let internalLoader: MTKTextureLoader
    private let cvMetalTextureBridging: MTICVMetalTextureBridging?
    private let error: Error?
    private let device: MTLDevice

    public init(device: MTLDevice) {
        self.device = device
        internalLoader = MTKTextureLoader(device: device)
        var bridge: MTICVMetalTextureBridging?
        var bridgeError: Error?
        do {
            bridge = try MTICVMetalIOSurfaceBridge.makeCoreVideoMetalTextureBridge(device: device)
        } catch {
            bridgeError = error
        }
        cvMetalTextureBridging = bridge
        error = bridgeError
        super.init()
    }

    public static func makeTextureLoader(device: MTLDevice) -> MTITextureLoader {
        MTIDefaultTextureLoader(device: device)
    }

    private func prefersCVPixelBufferLoader(for properties: MTIImageProperties?) -> Bool {
        guard let properties else {
            return false
        }
        if properties.byteOrderInfo == .order32Little,
           let colorSpace = properties.colorSpace,
           colorSpace.numberOfComponents == 3,
           colorSpace.model == .rgb,
           properties.bitsPerComponent == 8,
           let propertyList = colorSpace.copyPropertyList(),
           CFEqual(propertyList, CGColorSpace.sRGB)
        {
            return false
        }
        return true
    }

    private func newTextureWithCVPixelBuffer(
        from cgImage: CGImage,
        properties: MTIImageProperties,
        options: [MTKTextureLoader.Option: Any]?
    ) throws -> MTLTexture {
        if let error {
            throw error
        }

        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [String: Any]() as CFDictionary,
        ]
        var pixelBufferOut: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(properties.displayWidth),
            Int(properties.displayHeight),
            kCVPixelFormatType_32BGRA,
            pixelBufferAttributes as CFDictionary,
            &pixelBufferOut
        )
        guard let pixelBuffer = pixelBufferOut else {
            throw _MTIErrorCreate(.failedToCreateCVPixelBuffer, "MTIErrorFailedToCreateCVPixelBuffer", nil)
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        guard let cgContext = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(properties.displayWidth),
            height: Int(properties.displayHeight),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            throw _MTIErrorCreate(
                .textureLoaderFailedToCreateCGContext,
                "MTIErrorTextureLoaderFailedToCreateCGContext",
                nil
            )
        }

        var shouldFallbackToMTKTextureLoader = false
        if (options?[.allocateMipmaps] as? NSNumber)?.boolValue == true
            || (options?[.generateMipmaps] as? NSNumber)?.boolValue == true
            || options?[.cubeLayout] != nil
        {
            shouldFallbackToMTKTextureLoader = true
        }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Workaround for #64. See https://github.com/MetalPetal/MetalPetal/issues/64
        if !device.supportsFeatureSet(.iOS_GPUFamily2_v1) {
            shouldFallbackToMTKTextureLoader = true
        }
        #endif

        let imageRect = CGRect(x: 0, y: 0, width: Int(properties.pixelWidth), height: Int(properties.pixelHeight))
        let placeholder = CIImage(color: CIColor.black).cropped(to: imageRect)
        let orientationTransform = placeholder.orientationTransform(forExifOrientation: Int32(properties.orientation.rawValue))

        if shouldFallbackToMTKTextureLoader {
            // We do not currently support these features, so fallback to `MTKTextureLoader`. This may degrade
            // texture loading performance. (Loading a CVPixelBuffer is much faster.)
            cgContext.concatenate(orientationTransform)
            cgContext.draw(cgImage, in: imageRect)
            let sanitizedCGImage = cgContext.makeImage()
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            guard let sanitizedCGImage else {
                throw _MTIErrorCreate(
                    .textureLoaderFailedToCreateCGImage,
                    "MTIErrorTextureLoaderFailedToCreateCGImage",
                    nil
                )
            }
            return try internalLoader.newTexture(cgImage: sanitizedCGImage, options: options)
        } else {
            if let origin = options?[.origin] as? MTKTextureLoader.Origin,
               origin == .bottomLeft || origin == .flippedVertically
            {
                cgContext.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(properties.displayHeight)))
            }
            cgContext.concatenate(orientationTransform)
            cgContext.draw(cgImage, in: imageRect)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            var useSRGBTexture = true
            if let srgbOption = options?[.SRGB] {
                useSRGBTexture = (srgbOption as? NSNumber)?.boolValue ?? true
            }
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: useSRGBTexture ? .bgra8Unorm_srgb : .bgra8Unorm,
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer),
                mipmapped: false
            )
            if let usage = options?[.textureUsage] as? NSNumber {
                textureDescriptor.usage = MTLTextureUsage(rawValue: usage.uintValue)
            } else {
                textureDescriptor.usage = .shaderRead
            }
            if let storageMode = (options?[.textureStorageMode] as? NSNumber)?.uintValue,
               let mode = MTLStorageMode(rawValue: storageMode)
            {
                textureDescriptor.storageMode = mode
            }
            if let cacheMode = (options?[.textureCPUCacheMode] as? NSNumber)?.uintValue,
               let mode = MTLCPUCacheMode(rawValue: cacheMode)
            {
                textureDescriptor.cpuCacheMode = mode
            }
            guard let cvTexture = try cvMetalTextureBridging?.makeTexture(
                with: pixelBuffer,
                textureDescriptor: textureDescriptor,
                planeIndex: 0
            ) else {
                throw _MTIErrorCreate(.failedToCreateTexture, "MTIErrorFailedToCreateTexture", nil)
            }
            return cvTexture.texture
        }
    }

    public func newTexture(with cgImage: CGImage, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture {
        let properties = MTIImageProperties(cgImage: cgImage)
        if prefersCVPixelBufferLoader(for: properties) {
            return try newTextureWithCVPixelBuffer(from: cgImage, properties: properties, options: options)
        } else {
            return try internalLoader.newTexture(cgImage: cgImage, options: options)
        }
    }

    public func newTexture(withContentsOf url: URL, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture {
        let imageSourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceShouldAllowFloat: true,
        ]
        if let source = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions as CFDictionary),
           CGImageSourceGetCount(source) > 0,
           let properties = MTIImageProperties(imageSource: source, index: 0),
           prefersCVPixelBufferLoader(for: properties),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, imageSourceOptions as CFDictionary)
        {
            return try newTextureWithCVPixelBuffer(from: cgImage, properties: properties, options: options)
        }
        return try internalLoader.newTexture(URL: url, options: options)
    }

    public func newTexture(with mdlTexture: MDLTexture, options: [MTKTextureLoader.Option: Any]?) throws -> MTLTexture {
        try internalLoader.newTexture(texture: mdlTexture, options: options)
    }

    public func newTexture(
        withName name: String,
        scaleFactor: CGFloat,
        bundle: Bundle?,
        options: [MTKTextureLoader.Option: Any]?
    ) throws -> MTLTexture {
        try internalLoader.newTexture(name: name, scaleFactor: scaleFactor, bundle: bundle, options: options)
    }
}
