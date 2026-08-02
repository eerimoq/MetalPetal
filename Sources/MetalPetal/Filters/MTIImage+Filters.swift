//
//  MTIImage+Filters.swift
//  MetalPetal
//

import Foundation
import Metal

public extension MTIImage {
    func unpremultiplyingAlpha() -> MTIImage {
        MTIUnpremultiplyAlphaFilter.image(byProcessingImage: withCachePolicy(.transient))
            .withCachePolicy(cachePolicy)
    }

    func premultiplyingAlpha() -> MTIImage {
        MTIPremultiplyAlphaFilter.image(byProcessingImage: withCachePolicy(.transient))
            .withCachePolicy(cachePolicy)
    }

    func premultiplyingAlpha(outputPixelFormat pixelFormat: MTLPixelFormat) -> MTIImage {
        MTIPremultiplyAlphaFilter.image(
            byProcessingImage: withCachePolicy(.transient),
            outputPixelFormat: pixelFormat
        ).withCachePolicy(cachePolicy)
    }

    func unpremultiplyingAlpha(outputPixelFormat pixelFormat: MTLPixelFormat) -> MTIImage {
        MTIUnpremultiplyAlphaFilter.image(
            byProcessingImage: withCachePolicy(.transient),
            outputPixelFormat: pixelFormat
        ).withCachePolicy(cachePolicy)
    }

    func oriented(_ orientation: CGImagePropertyOrientation) -> MTIImage {
        oriented(orientation, outputPixelFormat: .unspecified)
    }

    func oriented(_ orientation: CGImagePropertyOrientation,
                  outputPixelFormat pixelFormat: MTLPixelFormat) -> MTIImage
    {
        if orientation == .up {
            return self
        }
        let imageOrientation: MTIImageOrientation = switch orientation {
        case .up:
            .up
        case .down:
            .down
        case .left:
            .right
        case .right:
            .left
        case .upMirrored:
            .upMirrored
        case .downMirrored:
            .downMirrored
        case .leftMirrored:
            .rightMirrored
        case .rightMirrored:
            .leftMirrored
        @unknown default:
            .unknown
        }
        return MTIUnaryImageRenderingFilter.image(byProcessingImage: withCachePolicy(.transient),
                                                  orientation: imageOrientation,
                                                  parameters: [:],
                                                  outputPixelFormat: pixelFormat).withCachePolicy(cachePolicy)
    }
}
