//
//  MTIBulgeDistortionFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/2/14.
//

import Foundation

public final class MTIBulgeDistortionFilter: MTIUnaryImageRenderingFilter {
    /// Specifies the center of the distortion in pixels.
    public var center: simd_float2 = simd_make_float2(0, 0)
    /// Specifies the radius of the distortion in pixels.
    public var radius: Float = 0
    /// Specifies the scale of the distortion, 0 being no-change.
    public var scale: Float = 0

    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "bulgeDistortion")
    }

    override public var parameters: [String: MTIFunctionArgumentValue] {
        ["center": .simd(.float2(center)),
         "radius": .float(radius),
         "scale": .float(scale)]
    }

    override public static func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        .passthrough
    }
}
