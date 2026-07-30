//
//  MTIColorHalftoneFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 17/01/2018.
//

import Foundation
import simd

public final class MTIColorHalftoneFilter: MTIUnaryImageRenderingFilter {
    /// Specifies the scale of the operation, i.e. the size for the pixels in the resulting image.
    public var scale: Float = 20
    /// Specifies the angles of the r, g, b channel.
    public var angles: simd_float4 = simd_make_float4(.pi / 4, .pi / 4, .pi / 4, 0)

    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "colorHalftone")
    }

    override public var parameters: [String: Any] {
        let allAnglesAreEqual = angles.x == angles.y && angles.y == angles.z
        return ["scale": max(scale, 1.0),
                "angles": MTIVector(value: angles),
                "singleAngleMode": allAnglesAreEqual]
    }

    override public static func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        MTIAlphaTypeHandlingRule.general
    }
}
