//
//  MTICVMetalTextureCache.swift
//  MetalPetal
//
//  Created by Yu Ao on 07/01/2018.
//

import CoreVideo
import Foundation
import Metal

public let MTICVMetalTextureCacheErrorDomain = "MTICVMetalTextureCacheErrorDomain"

public enum MTICVMetalTextureCacheError: Int {
    case metalIsNotSupported = 10001
    case failedToInitialize = 10002
    case failedToCreateTexture = 10003
}

private final class MTICVMetalTextureCacheTexture: NSObject, MTICVMetalTexture {
    let texture: MTLTexture

    // Keep the CVMetalTexture alive for the lifetime of this wrapper.
    private let textureRef: CVMetalTexture

    init(cvMetalTexture textureRef: CVMetalTexture) {
        self.textureRef = textureRef
        texture = CVMetalTextureGetTexture(textureRef)!
        super.init()
    }
}

/// Thread-safe object-orientated CVMetalTextureCache.
public final class MTICVMetalTextureCache: NSObject, MTICVMetalTextureBridging {
    private let cache: CVMetalTextureCache
    private let lock = MTILockCreate()

    public init(
        device: MTLDevice,
        cacheAttributes: [AnyHashable: Any]?,
        textureAttributes: [AnyHashable: Any]?
    ) throws {
        var cacheOut: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            cacheAttributes as CFDictionary?,
            device,
            textureAttributes as CFDictionary?,
            &cacheOut
        )
        guard status == kCVReturnSuccess, let cache = cacheOut else {
            throw NSError(
                domain: MTICVMetalTextureCacheErrorDomain,
                code: MTICVMetalTextureCacheError.failedToInitialize.rawValue,
                userInfo: [
                    NSUnderlyingErrorKey: NSError(
                        domain: NSOSStatusErrorDomain,
                        code: Int(status),
                        userInfo: [:]
                    ),
                ]
            )
        }
        self.cache = cache
        super.init()
    }

    public static func makeCoreVideoMetalTextureBridge(device: MTLDevice) throws
        -> MTICVMetalTextureBridging
    {
        try MTICVMetalTextureCache(device: device, cacheAttributes: nil, textureAttributes: nil)
    }

    public func makeTexture(
        with imageBuffer: CVImageBuffer,
        textureDescriptor: MTLTextureDescriptor,
        planeIndex: Int
    ) throws -> MTICVMetalTexture {
        lock.lock()
        let textureAttributes: [CFString: Any] = [
            kCVMetalTextureUsage: NSNumber(value: textureDescriptor.usage.rawValue),
            kCVMetalTextureStorageMode: NSNumber(value: textureDescriptor.storageMode.rawValue),
        ]
        var textureRefOut: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            imageBuffer,
            textureAttributes as CFDictionary,
            textureDescriptor.pixelFormat,
            textureDescriptor.width,
            textureDescriptor.height,
            planeIndex,
            &textureRefOut
        )
        lock.unlock()
        guard status == kCVReturnSuccess, let textureRef = textureRefOut else {
            flushCache()
            throw NSError(
                domain: MTICVMetalTextureCacheErrorDomain,
                code: MTICVMetalTextureCacheError.failedToCreateTexture.rawValue,
                userInfo: [
                    NSUnderlyingErrorKey: NSError(
                        domain: NSOSStatusErrorDomain,
                        code: Int(status),
                        userInfo: [:]
                    ),
                ]
            )
        }
        return MTICVMetalTextureCacheTexture(cvMetalTexture: textureRef)
    }

    public func flushCache() {
        lock.lock()
        CVMetalTextureCacheFlush(cache, 0)
        lock.unlock()
    }
}
