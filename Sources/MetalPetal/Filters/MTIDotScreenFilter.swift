//
//  MTIDotScreenFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 18/01/2018.
//

import Foundation
import simd

public final class MTIDotScreenFilter: MTIUnaryImageRenderingFilter {
    /// Specifies the angle of the effect.
    public var angle: Float = .pi / 4
    /// Specifies the scale of the operation, i.e. the size for the pixels in the resulting image.
    public var scale: Float = 12.0
    public var grayColorTransform: simd_float3 = MTIGrayColorTransformDefault

    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "dotScreen")
    }

    override public var parameters: [String: MTIFunctionArgumentValue] {
        ["angle": .float(angle),
         "scale": .float(max(scale, 1.0)),
         "grayColorTransform": .vector(MTIVector(value: grayColorTransform))]
    }

    override public static func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        MTIAlphaTypeHandlingRule.general
    }
}
