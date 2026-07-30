//
//  MTICVMetalIOSurfaceBridge.swift
//  MetalPetal
//
//  Created by Yu Ao on 2018/10/10.
//

import CoreVideo
import Foundation
import Metal

public let MTICVMetalIOSurfaceBridgeErrorDomain = "MTICVMetalIOSurfaceBridgeErrorDomain"

public enum MTICVMetalIOSurfaceBridgeError: Int {
    case imageBufferIsNotBackedByIOSurface = 10001
    case failedToCreateTexture = 10002
    case coreVideoDoesNotSupportIOSurface = 10003
}

private final class MTICVMetalIOSurfaceBridgeTexture: NSObject, MTICVMetalTexture {
    let texture: MTLTexture

    init(texture: MTLTexture) {
        self.texture = texture
        super.init()
    }
}

public final class MTICVMetalIOSurfaceBridge: NSObject, MTICVMetalTextureBridging {
    private let device: MTLDevice

    public init(device: MTLDevice) {
        self.device = device
        super.init()
    }

    public static func makeCoreVideoMetalTextureBridge(device: MTLDevice) throws -> MTICVMetalTextureBridging {
        MTICVMetalIOSurfaceBridge(device: device)
    }

    public func makeTexture(
        with imageBuffer: CVImageBuffer,
        textureDescriptor: MTLTextureDescriptor,
        planeIndex: Int
    ) throws -> MTICVMetalTexture {
        guard let ioSurface = CVPixelBufferGetIOSurface(imageBuffer)?.takeUnretainedValue() else {
            throw NSError(
                domain: MTICVMetalIOSurfaceBridgeErrorDomain,
                code: MTICVMetalIOSurfaceBridgeError.imageBufferIsNotBackedByIOSurface.rawValue,
                userInfo: [:]
            )
        }
        guard let texture = device.makeTexture(
            descriptor: textureDescriptor,
            iosurface: ioSurface,
            plane: planeIndex
        ) else {
            throw NSError(
                domain: MTICVMetalIOSurfaceBridgeErrorDomain,
                code: MTICVMetalIOSurfaceBridgeError.failedToCreateTexture.rawValue,
                userInfo: [:]
            )
        }
        return MTICVMetalIOSurfaceBridgeTexture(texture: texture)
    }

    public func flushCache() {}
}
