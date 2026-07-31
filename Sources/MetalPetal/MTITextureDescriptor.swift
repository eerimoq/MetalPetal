//
//  MTITextureDescriptor.swift
//  MetalPetal
//
//  Created by YuAo on 29/06/2017.
//

import Foundation
import Metal

/// An immutable wrapper for MTLTextureDescriptor.
public final class MTITextureDescriptor: Hashable {
    private let metalTextureDescriptor: MTLTextureDescriptor
    private let cachedHashValue: Int

    public init(mtlTextureDescriptor textureDescriptor: MTLTextureDescriptor) {
        metalTextureDescriptor = textureDescriptor.copy() as! MTLTextureDescriptor
        cachedHashValue = textureDescriptor.hash
    }

    public init(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        mipmapped: Bool,
        usage: MTLTextureUsage
    ) {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(width),
            height: Int(height),
            mipmapped: mipmapped
        )
        textureDescriptor.usage = usage
        metalTextureDescriptor = textureDescriptor
        cachedHashValue = textureDescriptor.hash
    }

    public init(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        mipmapped: Bool,
        usage: MTLTextureUsage,
        resourceOptions: MTLResourceOptions
    ) {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(width),
            height: Int(height),
            mipmapped: mipmapped
        )
        textureDescriptor.usage = usage
        textureDescriptor.resourceOptions = resourceOptions
        metalTextureDescriptor = textureDescriptor
        cachedHashValue = textureDescriptor.hash
    }

    public static func texture2DDescriptor(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        usage: MTLTextureUsage
    ) -> MTITextureDescriptor {
        MTITextureDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false,
            usage: usage
        )
    }

    public static func texture2DDescriptor(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        mipmapped: Bool,
        usage: MTLTextureUsage,
        resourceOptions: MTLResourceOptions
    ) -> MTITextureDescriptor {
        MTITextureDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: mipmapped,
            usage: usage,
            resourceOptions: resourceOptions
        )
    }

    public func makeMTLTextureDescriptor() -> MTLTextureDescriptor {
        metalTextureDescriptor.copy() as! MTLTextureDescriptor
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cachedHashValue)
    }

    public static func == (lhs: MTITextureDescriptor, rhs: MTITextureDescriptor) -> Bool {
        if lhs === rhs {
            return true
        }
        return lhs.metalTextureDescriptor.isEqual(rhs.metalTextureDescriptor)
    }

    public var textureType: MTLTextureType {
        metalTextureDescriptor.textureType
    }

    public var pixelFormat: MTLPixelFormat {
        metalTextureDescriptor.pixelFormat
    }

    public var width: Int {
        metalTextureDescriptor.width
    }

    public var height: Int {
        metalTextureDescriptor.height
    }

    public var depth: Int {
        metalTextureDescriptor.depth
    }

    public var resourceOptions: MTLResourceOptions {
        metalTextureDescriptor.resourceOptions
    }

    public var hazardTrackingMode: MTLHazardTrackingMode {
        metalTextureDescriptor.hazardTrackingMode
    }

    public func heapTextureSizeAndAlign(with device: MTLDevice) -> MTLSizeAndAlign {
        device.heapTextureSizeAndAlign(descriptor: metalTextureDescriptor)
    }

    public func makeTexture(device: MTLDevice) -> MTLTexture? {
        device.makeTexture(descriptor: metalTextureDescriptor)
    }

    public func makeTexture(heap: MTLHeap) -> MTLTexture? {
        heap.makeTexture(descriptor: metalTextureDescriptor)
    }
}

public extension MTLTextureDescriptor {
    func makeMTITextureDescriptor() -> MTITextureDescriptor {
        MTITextureDescriptor(mtlTextureDescriptor: self)
    }
}
