//
//  MTITextureDescriptor.swift
//  MetalPetal
//
//  Created by YuAo on 29/06/2017.
//

import Foundation
import Metal

/// An immutable wrapper for MTLTextureDescriptor.
public final class MTITextureDescriptor: NSObject, NSCopying {
    private let metalTextureDescriptor: MTLTextureDescriptor

    private let cachedHashValue: Int

    public init(mtlTextureDescriptor textureDescriptor: MTLTextureDescriptor) {
        metalTextureDescriptor = textureDescriptor.copy() as! MTLTextureDescriptor
        cachedHashValue = textureDescriptor.hash
        super.init()
    }

    public init(
        pixelFormat: MTLPixelFormat,
        width: UInt,
        height: UInt,
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
        super.init()
    }

    public init(
        pixelFormat: MTLPixelFormat,
        width: UInt,
        height: UInt,
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
        super.init()
    }

    public static func texture2DDescriptor(
        pixelFormat: MTLPixelFormat,
        width: UInt,
        height: UInt,
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
        width: UInt,
        height: UInt,
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

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    public func makeMTLTextureDescriptor() -> MTLTextureDescriptor {
        metalTextureDescriptor.copy() as! MTLTextureDescriptor
    }

    override public var hash: Int {
        cachedHashValue
    }

    override public func isEqual(_ object: Any?) -> Bool {
        if let other = object as? MTITextureDescriptor {
            if other === self {
                return true
            }
            return metalTextureDescriptor.isEqual(other.metalTextureDescriptor)
        }
        return false
    }

    public var textureType: MTLTextureType {
        metalTextureDescriptor.textureType
    }

    public var pixelFormat: MTLPixelFormat {
        metalTextureDescriptor.pixelFormat
    }

    public var width: UInt {
        UInt(metalTextureDescriptor.width)
    }

    public var height: UInt {
        UInt(metalTextureDescriptor.height)
    }

    public var depth: UInt {
        UInt(metalTextureDescriptor.depth)
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
