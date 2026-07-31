//
//  MTIImageProperties.swift
//  MetalPetal
//
//  Created by YuAo on 2018/6/22.
//

import CoreGraphics
import Foundation
import ImageIO

public final class MTIImageProperties {
    public let alphaInfo: CGImageAlphaInfo
    public let byteOrderInfo: CGImageByteOrderInfo
    public let floatComponents: Bool
    public let colorSpace: CGColorSpace?
    public let bitsPerComponent: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let orientation: CGImagePropertyOrientation
    // Width and height with orientation applied.
    public let displayWidth: Int
    public let displayHeight: Int
    public let properties: [AnyHashable: Any]

    private static var imageSourceOptions: [CFString: Any] {
        // Faster: kCGImageSourceSkipMetadata: true
        [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceShouldAllowFloat: true,
        ]
    }

    private static func displaySize(
        pixelWidth: Int,
        pixelHeight: Int,
        orientation: CGImagePropertyOrientation
    )
        -> (width: Int, height: Int)
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
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index,
                                                                  options) as? [AnyHashable: Any],
            let image = CGImageSourceCreateImageAtIndex(imageSource, index, options)
        else {
            return nil
        }
        self.properties = properties
        alphaInfo = image.alphaInfo
        byteOrderInfo = image.byteOrderInfo
        floatComponents = image.bitmapInfo.contains(.floatComponents)
        colorSpace = image.colorSpace
        pixelWidth = image.width
        pixelHeight = image.height
        bitsPerComponent = image.bitsPerComponent
        let orientationRawValue = (properties[kCGImagePropertyOrientation as String] as? NSNumber)?
            .uint32Value
        let orientation = orientationRawValue.flatMap { CGImagePropertyOrientation(rawValue: $0) } ?? .up
        self.orientation = orientation
        let displaySize = MTIImageProperties.displaySize(
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            orientation: orientation
        )
        displayWidth = displaySize.width
        displayHeight = displaySize.height
    }

    public init(cgImage image: CGImage, orientation: CGImagePropertyOrientation) {
        properties = [:]
        alphaInfo = image.alphaInfo
        byteOrderInfo = image.byteOrderInfo
        floatComponents = image.bitmapInfo.contains(.floatComponents)
        colorSpace = image.colorSpace
        pixelWidth = image.width
        pixelHeight = image.height
        bitsPerComponent = image.bitsPerComponent
        self.orientation = orientation
        let displaySize = MTIImageProperties.displaySize(
            pixelWidth: Int(image.width),
            pixelHeight: Int(image.height),
            orientation: orientation
        )
        displayWidth = displaySize.width
        displayHeight = displaySize.height
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
}
