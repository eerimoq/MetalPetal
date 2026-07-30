//
//  MTIFilter.swift
//  Pods
//
//  Created by YuAo on 25/06/2017.
//

import Foundation
import Metal

public let MTIFilterPassthroughVertexFunctionName = "passthroughVertex"
public let MTIFilterPassthroughFragmentFunctionName = "passthrough"
public let MTIFilterUnpremultiplyAlphaFragmentFunctionName = "unpremultiplyAlpha"
public let MTIFilterUnpremultiplyAlphaWithSRGBToLinearRGBFragmentFunctionName = "unpremultiplyAlphaWithSRGBToLinearRGB"
public let MTIFilterPremultiplyAlphaFragmentFunctionName = "premultiplyAlpha"
public let MTIFilterColorMatrixFragmentFunctionName = "colorMatrixProjection"

public protocol MTIFilter: AnyObject {
    /// Default: MTIPixelFormatUnspecified aka MTLPixelFormatInvalid
    var outputPixelFormat: MTLPixelFormat { get set }
    var outputImage: MTIImage? { get }
}

public protocol MTIUnaryFilter: MTIFilter {
    var inputImage: MTIImage? { get set }
}
