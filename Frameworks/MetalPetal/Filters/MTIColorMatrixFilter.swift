//
//  MTIColorMatrixFilter.swift
//  MetalPetal
//

import Foundation
import Metal
import simd

public let MTIColorMatrixFilterColorMatrixParameterKey = "colorMatrix"

public class MTIColorMatrixFilter: MTIUnaryImageRenderingFilter {
    public var colorMatrix: MTIColorMatrix = .identity

    override public class func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: MTIFilterColorMatrixFragmentFunctionName)
    }

    override public var parameters: [String: Any] {
        var matrix = colorMatrix
        let data = withUnsafeBytes(of: &matrix) { Data($0) }
        return [MTIColorMatrixFilterColorMatrixParameterKey: data]
    }

    override public class func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        MTIAlphaTypeHandlingRule.general
    }
}

public final class MTIExposureFilter: MTIColorMatrixFilter {
    /// Specifies the exposure, with 0 being no-change.
    public var exposure: Float = 0 {
        didSet { colorMatrix = MTIColorMatrix(exposure: exposure) }
    }
}

public final class MTISaturationFilter: MTIColorMatrixFilter {
    public var grayColorTransform: simd_float3 = MTIGrayColorTransformDefault {
        didSet { colorMatrix = MTIColorMatrix(saturation: saturation, grayColorTransform: grayColorTransform)
        }
    }

    /// Specifies the saturation. Saturation ranges from 0.0 (fully desaturated) to 2.0 (max saturation), with
    /// 1.0 as the normal level.
    public var saturation: Float = 1 {
        didSet { colorMatrix = MTIColorMatrix(saturation: saturation, grayColorTransform: grayColorTransform)
        }
    }

    override public init() {
        super.init()
        colorMatrix = MTIColorMatrix(saturation: saturation, grayColorTransform: grayColorTransform)
    }
}

public final class MTIColorInvertFilter: MTIColorMatrixFilter {
    override public init() {
        super.init()
        colorMatrix = MTIColorMatrix.rgbColorInvert
    }
}

public final class MTIOpacityFilter: MTIColorMatrixFilter {
    /// Specifies the opacity, with 0 being fully transparent, and 1 being no-change.
    public var opacity: Float = 1 {
        didSet { colorMatrix = MTIColorMatrix(opacity: opacity) }
    }
}

public final class MTIBrightnessFilter: MTIColorMatrixFilter {
    /// Specifies the brightness in the range of 0 to 1, with 0 being no-change.
    public var brightness: Float = 0 {
        didSet { colorMatrix = MTIColorMatrix(brightness: brightness) }
    }
}

public final class MTIContrastFilter: MTIColorMatrixFilter {
    /// Specifies the contrast, with 1 being no-change.
    public var contrast: Float = 1 {
        didSet { colorMatrix = MTIColorMatrix(contrast: contrast) }
    }
}
