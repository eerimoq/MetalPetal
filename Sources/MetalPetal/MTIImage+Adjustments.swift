//
//  MTIImage+Adjustments.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/12/4.
//

import CoreGraphics
import Foundation
import MetalKit

public extension MTIImage {
    func adjusting(saturation: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTISaturationFilter()
        filter.saturation = saturation
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    func adjusting(exposure: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTIExposureFilter()
        filter.exposure = exposure
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    func adjusting(brightness: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTIBrightnessFilter()
        filter.brightness = brightness
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    func adjusting(contrast: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTIContrastFilter()
        filter.contrast = contrast
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    func adjusting(vibrance: Float, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage {
        let filter = MTIVibranceFilter()
        filter.amount = vibrance
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage!
    }

    /// Returns a MTIImage object that specifies a subimage of the image. If the `region` parameter defines an
    /// empty area, returns nil.
    func cropped(to region: MTICropRegion, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage? {
        let filter = MTICropFilter()
        filter.cropRegion = region
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage
    }

    /// Returns a MTIImage object that specifies a subimage of the image. If the `rect` parameter defines an
    /// empty area, returns nil.
    func cropped(to rect: CGRect, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage? {
        let filter = MTICropFilter()
        filter.cropRegion = MTICropRegion(bounds: rect, unit: .pixel)
        filter.inputImage = self
        filter.outputPixelFormat = outputPixelFormat
        return filter.outputImage
    }

    /// Returns a MTIImage object that is resized to a specified size. If the `size` parameter has
    /// zero/negative width or height, returns nil.
    func resized(to size: CGSize, outputPixelFormat: MTLPixelFormat = .unspecified) -> MTIImage? {
        assert(size.width >= 1 && size.height >= 1)
        guard size.width >= 1, size.height >= 1 else { return nil }
        return MTIUnaryImageRenderingFilter.image(
            byProcessingImage: self,
            orientation: .up,
            parameters: [:],
            outputPixelFormat: outputPixelFormat,
            outputImageSize: size
        )
    }

    /// Returns a MTIImage object that is resized to a specified size. If the `size` parameter has
    /// zero/negative width or height, returns nil.
    func resized(
        to target: CGSize,
        resizingMode: MTIDrawableRenderingResizingMode,
        outputPixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage? {
        let size: CGSize = switch resizingMode {
        case .aspect:
            MTIMakeRect(aspectRatio: self.size, insideRect: CGRect(origin: .zero, size: target)).size
        case .aspectFill:
            MTIMakeRect(aspectRatio: self.size, fillRect: CGRect(origin: .zero, size: target)).size
        case .scale:
            target
        }
        assert(size.width >= 1 && size.height >= 1)
        guard size.width >= 1, size.height >= 1 else { return nil }
        return MTIUnaryImageRenderingFilter.image(
            byProcessingImage: self,
            orientation: .up,
            parameters: [:],
            outputPixelFormat: outputPixelFormat,
            outputImageSize: size
        )
    }
}

#if canImport(UIKit)

import UIKit

fileprivate extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        @unknown default:
            fatalError("Unknown UIImage.Orientation: \(rawValue)")
        }
    }
}

public extension MTIImage {
    convenience init(image: UIImage, colorSpace: CGColorSpace? = nil, isOpaque: Bool = false) {
        let cgImage: CGImage
        let orientation: CGImagePropertyOrientation
        if let cg = image.cgImage {
            cgImage = cg
            orientation = image.imageOrientation.cgImagePropertyOrientation
        } else {
            let format = UIGraphicsImageRendererFormat.preferred()
            format.opaque = isOpaque
            format.scale = image.scale
            cgImage = UIGraphicsImageRenderer(size: image.size).image { _ in
                image.draw(at: .zero)
            }.cgImage!
            orientation = .up
        }
        let options = MTICGImageLoadingOptions(colorSpace: colorSpace)
        self.init(cgImage: cgImage, orientation: orientation, options: options, isOpaque: isOpaque)
    }
}

#endif

#if canImport(AppKit)

import AppKit

public extension MTIImage {
    @available(macCatalyst, unavailable)
    convenience init?(image: NSImage, colorSpace: CGColorSpace? = nil, isOpaque: Bool = false) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let options = MTICGImageLoadingOptions(colorSpace: colorSpace)
        self.init(cgImage: cgImage, orientation: .up, options: options, isOpaque: isOpaque)
    }
}

#endif
