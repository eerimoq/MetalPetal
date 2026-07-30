//
//  MTIRenderPassOutputDescriptor.swift
//  MetalPetal
//
//  Created by YuAo on 18/11/2017.
//

import Foundation
import Metal

public final class MTIRenderPassOutputDescriptor: NSObject, NSCopying {
    public let dimensions: MTITextureDimensions
    public let pixelFormat: MTLPixelFormat
    public let loadAction: MTLLoadAction
    public let storeAction: MTLStoreAction
    public let clearColor: MTLClearColor

    public init(
        dimensions: MTITextureDimensions,
        pixelFormat: MTLPixelFormat,
        clearColor: MTLClearColor,
        loadAction: MTLLoadAction,
        storeAction: MTLStoreAction
    ) {
        self.dimensions = dimensions
        self.pixelFormat = pixelFormat
        self.clearColor = clearColor
        self.loadAction = loadAction
        self.storeAction = storeAction
        super.init()
    }

    public convenience init(dimensions: MTITextureDimensions, pixelFormat: MTLPixelFormat) {
        self.init(dimensions: dimensions, pixelFormat: pixelFormat, loadAction: .dontCare)
    }

    public convenience init(
        dimensions: MTITextureDimensions,
        pixelFormat: MTLPixelFormat,
        loadAction: MTLLoadAction
    ) {
        self.init(
            dimensions: dimensions,
            pixelFormat: pixelFormat,
            loadAction: loadAction,
            storeAction: .store
        )
    }

    public convenience init(
        dimensions: MTITextureDimensions,
        pixelFormat: MTLPixelFormat,
        loadAction: MTLLoadAction,
        storeAction: MTLStoreAction
    ) {
        self.init(
            dimensions: dimensions,
            pixelFormat: pixelFormat,
            clearColor: MTLClearColorMake(0, 0, 0, 0),
            loadAction: loadAction,
            storeAction: storeAction
        )
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(dimensions.width)
        hasher.combine(dimensions.height)
        hasher.combine(dimensions.depth)
        hasher.combine(pixelFormat)
        hasher.combine(loadAction)
        hasher.combine(storeAction)
        hasher.combine(clearColor.red)
        hasher.combine(clearColor.green)
        hasher.combine(clearColor.blue)
        hasher.combine(clearColor.alpha)
        return hasher.finalize()
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? MTIRenderPassOutputDescriptor else {
            return false
        }
        return isEqual(to: object)
    }

    public func isEqual(to object: MTIRenderPassOutputDescriptor) -> Bool {
        dimensions.width == object.dimensions.width &&
            dimensions.height == object.dimensions.height &&
            dimensions.depth == object.dimensions.depth &&
            pixelFormat == object.pixelFormat &&
            loadAction == object.loadAction &&
            storeAction == object.storeAction &&
            clearColor.red == object.clearColor.red &&
            clearColor.green == object.clearColor.green &&
            clearColor.blue == object.clearColor.blue &&
            clearColor.alpha == object.clearColor.alpha
    }
}
