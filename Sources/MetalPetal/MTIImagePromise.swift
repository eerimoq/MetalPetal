//
//  MTIImagePromise.swift
//  Pods
//
//  Created by YuAo on 27/06/2017.
//

import CoreImage
import CoreVideo
import Foundation
import Metal
import MetalKit
import ModelIO
import simd

public protocol MTIImagePromise: AnyObject {
    var dimensions: MTITextureDimensions { get }
    var dependencies: [MTIImage] { get }
    var alphaType: MTIAlphaType { get }
    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget
    func updatingDependencies(_ dependencies: [MTIImage]) -> Self
    var debugInfo: MTIImagePromiseDebugInfo { get }
}

private func MTIImagePromiseOptimizeContentsForGPUAccess(
    _ texture: MTLTexture,
    _ renderingContext: MTIImageRenderingContext
) {
    if #available(iOS 12.0, macOS 10.14, *) {
        let blitCommandEncoder = renderingContext.commandBuffer.makeBlitCommandEncoder()
        blitCommandEncoder?.optimizeContentsForGPUAccess(texture: texture)
        blitCommandEncoder?.endEncoding()
    }
}

public final class MTIImageURLPromise: MTIImagePromise {
    private let url: URL
    private let options: [MTKTextureLoader.Option: Any]?

    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init?(
        contentsOf url: URL,
        dimensions: MTITextureDimensions,
        options: [MTKTextureLoader.Option: Any]?,
        alphaType: MTIAlphaType
    ) {
        self.url = url
        self.options = options
        self.alphaType = alphaType
        self.dimensions = dimensions
        if dimensions.depth * dimensions.height * dimensions.width == 0 {
            return nil
        }
    }

    public var dependencies: [MTIImage] {
        []
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let texture = try renderingContext.context.textureLoader.newTexture(
            withContentsOf: url,
            options: options
        )
        MTIImagePromiseOptimizeContentsForGPUAccess(texture, renderingContext)
        return renderingContext.context.makeRenderTarget(texture: texture)
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: url)
    }
}

public final class MTILegacyCGImagePromise: MTIImagePromise {
    private let image: CGImage
    private let options: [MTKTextureLoader.Option: Any]?

    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init(cgImage: CGImage, options: [MTKTextureLoader.Option: Any]?, alphaType: MTIAlphaType) {
        image = cgImage
        dimensions = MTITextureDimensions(width: cgImage.width, height: cgImage.height, depth: 1)
        self.options = options
        self.alphaType = alphaType
    }

    public var dependencies: [MTIImage] {
        []
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let texture = try renderingContext.context.textureLoader.newTexture(with: image, options: options)
        MTIImagePromiseOptimizeContentsForGPUAccess(texture, renderingContext)
        return renderingContext.context.makeRenderTarget(texture: texture)
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: image)
    }
}

public final class MTICGImageLoadingOptions {
    public let colorSpace: CGColorSpace?
    public let flipsVertically: Bool
    public let storageMode: MTLStorageMode
    public let cpuCacheMode: MTLCPUCacheMode

    private static let defaultTextureDescriptor = MTLTextureDescriptor()

    public static let `default` = MTICGImageLoadingOptions(colorSpace: CGColorSpaceCreateDeviceRGB())

    public init(
        colorSpace: CGColorSpace?,
        flipsVertically: Bool,
        storageMode: MTLStorageMode,
        cpuCacheMode: MTLCPUCacheMode
    ) {
        self.colorSpace = colorSpace
        self.flipsVertically = flipsVertically
        self.storageMode = storageMode
        self.cpuCacheMode = cpuCacheMode
    }

    public convenience init(colorSpace: CGColorSpace?) {
        self.init(
            colorSpace: colorSpace,
            flipsVertically: false,
            storageMode: MTICGImageLoadingOptions.defaultTextureDescriptor.storageMode,
            cpuCacheMode: MTICGImageLoadingOptions.defaultTextureDescriptor.cpuCacheMode
        )
    }

    public convenience init(colorSpace: CGColorSpace?, flipsVertically: Bool) {
        self.init(
            colorSpace: colorSpace,
            flipsVertically: flipsVertically,
            storageMode: MTICGImageLoadingOptions.defaultTextureDescriptor.storageMode,
            cpuCacheMode: MTICGImageLoadingOptions.defaultTextureDescriptor.cpuCacheMode
        )
    }
}

public final class MTICGImagePromise: MTIImagePromise {
    private let image: CGImage
    private let options: MTICGImageLoadingOptions
    private let properties: MTIImageProperties
    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        options: MTICGImageLoadingOptions?,
        isOpaque: Bool
    ) {
        properties = MTIImageProperties(cgImage: cgImage, orientation: orientation)
        image = cgImage
        dimensions = MTITextureDimensions(
            width: properties.displayWidth,
            height: properties.displayHeight,
            depth: 1
        )
        self.options = options ?? MTICGImageLoadingOptions.default
        alphaType = isOpaque ? .alphaIsOne : .premultiplied
    }

    public var dependencies: [MTIImage] {
        []
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let pixelWidth = Int(properties.pixelWidth)
        let pixelHeight = Int(properties.pixelHeight)
        let displayWidth = Int(properties.displayWidth)
        let displayHeight = Int(properties.displayHeight)
        var pixelBufferOut: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            displayWidth,
            displayHeight,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [AnyHashable: Any]] as CFDictionary,
            &pixelBufferOut
        )
        guard let pixelBuffer = pixelBufferOut else {
            throw MTIError.failedToCreateCVPixelBuffer
        }
        let specifiedColorSpace = options.colorSpace ?? image.colorSpace
        let colorSpace = if let specifiedColorSpace, specifiedColorSpace.model == .rgb {
            specifiedColorSpace
        } else {
            CGColorSpaceCreateDeviceRGB()
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard let cgContext = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: displayWidth,
            height: displayHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            throw MTIError.textureLoaderFailedToCreateCGContext
        }
        let placeholder = CIImage(color: CIColor.black).cropped(to: CGRect(
            x: 0,
            y: 0,
            width: pixelWidth,
            height: pixelHeight
        ))
        if options.flipsVertically {
            cgContext.concatenate(CGAffineTransform(
                a: 1,
                b: 0,
                c: 0,
                d: -1,
                tx: 0,
                ty: CGFloat(displayHeight)
            ))
        }
        cgContext
            .concatenate(placeholder
                .orientationTransform(forExifOrientation: Int32(properties.orientation.rawValue)))
        cgContext.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        guard let iosurface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            throw MTIError.failedToCreateTexture
        }
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            mipmapped: false
        )
        textureDescriptor.usage = .shaderRead
        textureDescriptor.storageMode = options.storageMode
        textureDescriptor.cpuCacheMode = options.cpuCacheMode
        guard let texture = renderingContext.context.device.makeTexture(
            descriptor: textureDescriptor,
            iosurface: iosurface,
            plane: 0
        ) else {
            throw MTIError.failedToCreateTexture
        }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Workaround for #64. See https://github.com/MetalPetal/MetalPetal/issues/64
        if !renderingContext.context.device.supportsFamily(.apple2) {
            let renderTarget = try renderingContext.context
                .makeRenderTarget(reusableTextureDescriptor: textureDescriptor.makeMTITextureDescriptor())
            guard let commandEncoder = renderingContext.commandBuffer.makeBlitCommandEncoder() else {
                throw MTIError.failedToCreateCommandEncoder
            }
            commandEncoder.copy(
                from: texture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: texture.width, height: texture.height, depth: texture.depth),
                to: renderTarget.texture!,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            commandEncoder.endEncoding()
            return renderTarget
        }
        #endif

        MTIImagePromiseOptimizeContentsForGPUAccess(texture, renderingContext)
        return renderingContext.context.makeRenderTarget(texture: texture)
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: image)
    }
}

public final class MTITexturePromise: MTIImagePromise {
    public let texture: MTLTexture
    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init(texture: MTLTexture, alphaType: MTIAlphaType) {
        dimensions = MTITextureDimensions(width: texture.width, height: texture.height, depth: texture.depth)
        self.texture = texture
        self.alphaType = alphaType
    }

    public var dependencies: [MTIImage] {
        []
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        if renderingContext.context.device !== texture.device {
            throw MTIError.crossDeviceRendering
        }
        return renderingContext.context.makeRenderTarget(texture: texture)
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: texture)
    }
}

public final class MTICIImagePromise: MTIImagePromise {
    private let image: CIImage
    private let bounds: CGRect
    private let textureDescriptor: MTITextureDescriptor
    private let isOpaque: Bool
    private let options: MTICIImageRenderingOptions
    public let dimensions: MTITextureDimensions

    public init(ciImage: CIImage, bounds: CGRect, isOpaque: Bool, options: MTICIImageRenderingOptions) {
        image = ciImage
        self.bounds = bounds
        self.isOpaque = isOpaque
        dimensions = MTITextureDimensions(
            width: Int(ciImage.extent.size.width),
            height: Int(ciImage.extent.size.height),
            depth: 1
        )
        textureDescriptor = MTITextureDescriptor(
            pixelFormat: options.destinationPixelFormat,
            width: Int(ciImage.extent.size.width),
            height: Int(ciImage.extent.size.height),
            mipmapped: false,
            usage: [.shaderWrite, .shaderRead],
            resourceOptions: .storageModePrivate
        )
        self.options = options
    }

    public var dependencies: [MTIImage] {
        []
    }

    public var alphaType: MTIAlphaType {
        if isOpaque {
            return .alphaIsOne
        } else {
            switch options.alphaMode {
            case .none:
                return .alphaIsOne
            case .premultiplied:
                return .premultiplied
            case .unpremultiplied:
                return .nonPremultiplied
            @unknown default:
                return .premultiplied
            }
        }
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let renderTarget = try renderingContext.context
            .makeRenderTarget(reusableTextureDescriptor: textureDescriptor)
        let renderDestination = CIRenderDestination(
            mtlTexture: renderTarget.texture!,
            commandBuffer: renderingContext.commandBuffer
        )
        renderDestination.isFlipped = options.isFlipped
        renderDestination.colorSpace = options.colorSpace
        renderDestination.alphaMode = options.alphaMode
        try renderingContext.context.coreImageContext.startTask(
            toRender: image,
            from: bounds,
            to: renderDestination,
            at: .zero
        )
        return renderTarget
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: image)
    }
}

public final class MTIColorImagePromise: MTIImagePromise {
    public let color: MTIColor
    private let sRGB: Bool
    public let dimensions: MTITextureDimensions

    public init(color: MTIColor, sRGB: Bool, size: CGSize) {
        dimensions = MTITextureDimensions(width: Int(size.width), height: Int(size.height), depth: 1)
        self.color = color
        self.sRGB = sRGB
    }

    public var dependencies: [MTIImage] {
        []
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 1
        textureDescriptor.height = 1
        textureDescriptor.depth = 1
        textureDescriptor.textureType = .type2D
        textureDescriptor.usage = .shaderRead
        textureDescriptor.pixelFormat = sRGB ? .bgra8Unorm_srgb : .bgra8Unorm
        // It's not safe to reuse a GPU texture here, 'cause we're going to fill its content using CPU.
        guard let texture = renderingContext.context.device.makeTexture(descriptor: textureDescriptor) else {
            throw MTIError.failedToCreateTexture
        }
        let floatColor = simd_clamp(
            color.toFloat4(),
            simd_make_float4(0, 0, 0, 0),
            simd_make_float4(1, 1, 1, 1)
        ) * 255.0
        var colors: [UInt8] = [
            UInt8(floatColor.z.rounded()),
            UInt8(floatColor.y.rounded()),
            UInt8(floatColor.x.rounded()),
            UInt8(floatColor.w.rounded()),
        ]
        texture.replace(
            region: MTLRegionMake2D(0, 0, textureDescriptor.width, textureDescriptor.height),
            mipmapLevel: 0,
            slice: 0,
            withBytes: &colors,
            bytesPerRow: 4 * textureDescriptor.width,
            bytesPerImage: 4 * textureDescriptor.width * textureDescriptor.height
        )
        MTIImagePromiseOptimizeContentsForGPUAccess(texture, renderingContext)
        return renderingContext.context.makeRenderTarget(texture: texture)
    }

    public var alphaType: MTIAlphaType {
        if color.alpha == 1 {
            return .alphaIsOne
        }
        return .nonPremultiplied
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(
            promise: self,
            type: .source,
            content: [color.red, color.green, color.blue, color.alpha]
        )
    }
}

public final class MTIBitmapDataImagePromise: MTIImagePromise {
    private let data: Data
    private let pixelFormat: MTLPixelFormat
    private let bytesPerRow: Int
    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init(
        bitmapData data: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixelFormat: MTLPixelFormat,
        alphaType: MTIAlphaType
    ) {
        self.data = data
        dimensions = MTITextureDimensions(width: Int(width), height: Int(height), depth: 1)
        self.pixelFormat = pixelFormat
        self.alphaType = alphaType
        self.bytesPerRow = bytesPerRow
    }

    public var dependencies: [MTIImage] {
        []
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = dimensions.width
        textureDescriptor.height = dimensions.height
        textureDescriptor.depth = dimensions.depth
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = pixelFormat
        textureDescriptor.usage = .shaderRead
        // It's not safe to reuse a GPU texture here, 'cause we're going to fill its content using CPU.
        guard let texture = renderingContext.context.device.makeTexture(descriptor: textureDescriptor) else {
            throw MTIError.failedToCreateTexture
        }
        data.withUnsafeBytes { rawBuffer in
            texture.replace(
                region: MTLRegionMake2D(0, 0, textureDescriptor.width, textureDescriptor.height),
                mipmapLevel: 0,
                slice: 0,
                withBytes: rawBuffer.baseAddress!,
                bytesPerRow: Int(bytesPerRow),
                bytesPerImage: Int(bytesPerRow) * textureDescriptor.height
            )
        }
        MTIImagePromiseOptimizeContentsForGPUAccess(texture, renderingContext)
        return renderingContext.context.makeRenderTarget(texture: texture)
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: "BitmapData")
    }
}

public final class MTINamedImagePromise: MTIImagePromise {
    public let name: String
    public let bundle: Bundle?
    public let scaleFactor: CGFloat
    private let options: [MTKTextureLoader.Option: Any]?
    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init(
        name: String,
        bundle: Bundle?,
        size: CGSize,
        scaleFactor: CGFloat,
        options: [MTKTextureLoader.Option: Any]?,
        alphaType: MTIAlphaType
    ) {
        self.name = name
        self.bundle = bundle
        dimensions = MTITextureDimensions(cgSize: size)
        self.scaleFactor = scaleFactor
        self.options = options
        self.alphaType = alphaType
    }

    public var dependencies: [MTIImage] {
        []
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let texture = try renderingContext.context.textureLoader.newTexture(
            withName: name,
            scaleFactor: scaleFactor,
            bundle: bundle,
            options: options
        )
        if texture.width == dimensions.width, texture.height == dimensions.height,
           texture.depth == dimensions.depth
        {
            return renderingContext.context.makeRenderTarget(texture: texture)
        } else {
            throw MTIError.textureDimensionsMismatch
        }
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(
            promise: self,
            type: .source,
            content: """
            Name: \(name)\n\
            Bundle: \(String(describing: bundle))\n\
            Scale: \(scaleFactor)\n\
            Size: \(CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height)))
            """
        )
    }
}

public final class MTIMDLTexturePromise: MTIImagePromise {
    private let options: [MTKTextureLoader.Option: Any]?
    private let texture: MDLTexture
    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init(
        mdlTexture texture: MDLTexture,
        options: [MTKTextureLoader.Option: Any]?,
        alphaType: MTIAlphaType
    ) {
        self.texture = texture
        self.options = options
        dimensions = MTITextureDimensions(
            width: Int(texture.dimensions.x),
            height: texture.isCube ? Int(texture.dimensions.y) / 6 : Int(texture.dimensions.y),
            depth: 1
        )
        self.alphaType = alphaType
    }

    public var dependencies: [MTIImage] {
        []
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let texture = try renderingContext.context.textureLoader.newTexture(with: texture, options: options)
        if texture.width == dimensions.width, texture.height == dimensions.height,
           texture.depth == dimensions.depth
        {
            return renderingContext.context.makeRenderTarget(texture: texture)
        } else {
            throw MTIError.textureDimensionsMismatch
        }
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(
            promise: self,
            type: .source,
            content: "Name: \(String(describing: texture.name))\nTexture:\(texture)"
        )
    }
}
