//
//  MTIImageProperties.swift
//  MetalPetal
//
//  Created by YuAo on 2018/6/22.
//

import CoreGraphics
import Foundation
import ImageIO

public final class MTIImageProperties: NSObject, NSCopying {
    public let alphaInfo: CGImageAlphaInfo
    public let byteOrderInfo: CGImageByteOrderInfo
    public let floatComponents: Bool
    public let colorSpace: CGColorSpace?

    public let bitsPerComponent: UInt

    public let pixelWidth: UInt
    public let pixelHeight: UInt

    public let orientation: CGImagePropertyOrientation

    // Width and height with orientation applied.
    public let displayWidth: UInt
    public let displayHeight: UInt

    public let properties: [AnyHashable: Any]

    private static var imageSourceOptions: [CFString: Any] {
        // Faster: kCGImageSourceSkipMetadata: true
        [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceShouldAllowFloat: true,
        ]
    }

    private static func displaySize(pixelWidth: UInt, pixelHeight: UInt, orientation: CGImagePropertyOrientation)
        -> (width: UInt, height: UInt)
    {
        switch orientation {
        case .up, .down, .upMirrored, .downMirrored:
            return (pixelWidth, pixelHeight)
        case .left, .right, .leftMirrored, .rightMirrored:
            return (pixelHeight, pixelWidth)
        @unknown default:
            return (pixelWidth, pixelHeight)
        }
    }

    public init?(imageSource: CGImageSource, index: Int) {
        guard index < CGImageSourceGetCount(imageSource) else {
            return nil
        }
        let options = MTIImageProperties.imageSourceOptions as CFDictionary
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, options) as? [AnyHashable: Any],
              let image = CGImageSourceCreateImageAtIndex(imageSource, index, options)
        else {
            return nil
        }
        self.properties = properties
        alphaInfo = image.alphaInfo
        byteOrderInfo = image.byteOrderInfo
        floatComponents = image.bitmapInfo.contains(.floatComponents)
        colorSpace = image.colorSpace
        pixelWidth = UInt(image.width)
        pixelHeight = UInt(image.height)
        bitsPerComponent = UInt(image.bitsPerComponent)

        let orientationRawValue = (properties[kCGImagePropertyOrientation as String] as? NSNumber)?.uint32Value
        let orientation = orientationRawValue.flatMap { CGImagePropertyOrientation(rawValue: $0) } ?? .up
        self.orientation = orientation

        let displaySize = MTIImageProperties.displaySize(
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            orientation: orientation
        )
        displayWidth = displaySize.width
        displayHeight = displaySize.height

        super.init()
    }

    public init(cgImage image: CGImage, orientation: CGImagePropertyOrientation) {
        properties = [:]
        alphaInfo = image.alphaInfo
        byteOrderInfo = image.byteOrderInfo
        floatComponents = image.bitmapInfo.contains(.floatComponents)
        colorSpace = image.colorSpace
        pixelWidth = UInt(image.width)
        pixelHeight = UInt(image.height)
        bitsPerComponent = UInt(image.bitsPerComponent)
        self.orientation = orientation

        let displaySize = MTIImageProperties.displaySize(
            pixelWidth: UInt(image.width),
            pixelHeight: UInt(image.height),
            orientation: orientation
        )
        displayWidth = displaySize.width
        displayHeight = displaySize.height

        super.init()
    }

    public convenience init(cgImage image: CGImage) {
        self.init(cgImage: image, orientation: .up)
    }

    public convenience init?(imageAt url: URL) {
        let options = MTIImageProperties.imageSourceOptions as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            return nil
        }
        self.init(imageSource: source, index: 0)
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }
}
