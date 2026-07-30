//
//  MTIMultilayerCompositingFilter.swift
//  MetalPetal
//

import Foundation
import Metal

/// A filter that allows you to compose multiple `MTILayer` objects onto a background image. A
/// `MTIMultilayerCompositingFilter` object skips the actual rendering when its `layers.count` is zero.
public final class MTIMultilayerCompositingFilter: NSObject, MTIFilter {
    public var inputBackgroundImage: MTIImage?
    public var layers: [MTILayer] = []
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var rasterSampleCount: UInt = 1
    /// Specifies the alpha type of output image. If `.alphaIsOne` is assigned, the alpha channel of
    /// the output image will be set to 1. The default value for this property is `.nonPremultiplied`.
    public var outputAlphaType: MTIAlphaType = .nonPremultiplied
    private static let kernel = MTIMultilayerCompositeKernel()

    public var outputImage: MTIImage? {
        guard let inputBackgroundImage else {
            return nil
        }
        if layers.isEmpty {
            return inputBackgroundImage
        }
        return MTIMultilayerCompositingFilter.kernel.apply(
            toBackgroundImage: inputBackgroundImage,
            layers: layers,
            rasterSampleCount: rasterSampleCount,
            outputAlphaType: outputAlphaType,
            outputTextureDimensions: MTITextureDimensions(cgSize: inputBackgroundImage.size),
            outputPixelFormat: outputPixelFormat
        )
    }
}
