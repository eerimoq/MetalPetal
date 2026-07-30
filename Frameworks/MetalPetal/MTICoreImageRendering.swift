//
//  MTICoreImageRendering.swift
//  MetalPetal
//
//  Created by Yu Ao on 04/04/2018.
//

import CoreGraphics
import CoreImage
import Foundation
import Metal

public final class MTICIImageRenderingOptions: NSObject, NSCopying {
    public let colorSpace: CGColorSpace?
    public let isFlipped: Bool
    public let destinationPixelFormat: MTLPixelFormat
    public let alphaMode: CIRenderDestinationAlphaMode

    public init(
        destinationPixelFormat pixelFormat: MTLPixelFormat,
        alphaMode: CIRenderDestinationAlphaMode,
        colorSpace: CGColorSpace?,
        flipped: Bool
    ) {
        destinationPixelFormat = pixelFormat
        self.alphaMode = alphaMode
        self.colorSpace = colorSpace
        isFlipped = flipped
        super.init()
    }

    public convenience init(
        destinationPixelFormat pixelFormat: MTLPixelFormat,
        colorSpace: CGColorSpace?,
        flipped: Bool
    ) {
        self.init(
            destinationPixelFormat: pixelFormat,
            alphaMode: .premultiplied,
            colorSpace: colorSpace,
            flipped: flipped
        )
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    public static let `default` = MTICIImageRenderingOptions(
        destinationPixelFormat: .bgra8Unorm,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        flipped: true
    )
}

public final class MTICIImageCreationOptions: NSObject, NSCopying {
    public let colorSpace: CGColorSpace?
    public let isFlipped: Bool

    public init(colorSpace: CGColorSpace?, flipped: Bool) {
        self.colorSpace = colorSpace
        isFlipped = flipped
        super.init()
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    public static let `default` = MTICIImageCreationOptions(
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        flipped: true
    )
}
