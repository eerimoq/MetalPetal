//
//  MTIRenderPassOutputDescriptor.swift
//  MetalPetal
//
//  Created by YuAo on 18/11/2017.
//

import Foundation
import Metal

public final class MTIRenderPassOutputDescriptor: Hashable {
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

    public func hash(into hasher: inout Hasher) {
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
    }

    public static func == (
        lhs: MTIRenderPassOutputDescriptor,
        rhs: MTIRenderPassOutputDescriptor
    ) -> Bool {
        lhs.dimensions == rhs.dimensions &&
            lhs.pixelFormat == rhs.pixelFormat &&
            lhs.loadAction == rhs.loadAction &&
            lhs.storeAction == rhs.storeAction &&
            lhs.clearColor.red == rhs.clearColor.red &&
            lhs.clearColor.green == rhs.clearColor.green &&
            lhs.clearColor.blue == rhs.clearColor.blue &&
            lhs.clearColor.alpha == rhs.clearColor.alpha
    }
}
