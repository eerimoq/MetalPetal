//
//  MTICVMetalIOSurfaceBridge.swift
//  MetalPetal
//
//  Created by Yu Ao on 2018/10/10.
//

import CoreVideo
import Foundation
import Metal

private final class MTICVMetalIOSurfaceBridgeTexture: MTICVMetalTexture {
    let texture: MTLTexture

    init(texture: MTLTexture) {
        self.texture = texture
    }
}

public final class MTICVMetalIOSurfaceBridge: MTICVMetalTextureBridging {
    private let device: MTLDevice

    public init(device: MTLDevice) {
        self.device = device
    }

    public func makeTexture(
        with imageBuffer: CVImageBuffer,
        textureDescriptor: MTLTextureDescriptor,
        planeIndex: Int
    ) throws -> MTICVMetalTexture {
        guard let ioSurface = CVPixelBufferGetIOSurface(imageBuffer)?.takeUnretainedValue() else {
            throw MTIError.imageBufferIsNotBackedByIOSurface
        }
        guard let texture = device.makeTexture(
            descriptor: textureDescriptor,
            iosurface: ioSurface,
            plane: planeIndex
        ) else {
            throw MTIError.failedToCreateTexture
        }
        return MTICVMetalIOSurfaceBridgeTexture(texture: texture)
    }

    public func flushCache() {}
}
