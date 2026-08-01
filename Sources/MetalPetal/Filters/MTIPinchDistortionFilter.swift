//
//  MTIPinchDistortionFilter.swift
//  MetalPetal
//

import Foundation
import simd

public final class MTIPinchDistortionFilter: MTIUnaryImageRenderingFilter {
    /// Specifies the center of the distortion in pixels.
    public var center: simd_float2 = simd_make_float2(0, 0)
    /// Specifies the radius of the distortion in pixels. Pixels at this distance from the center are
    /// unaffected.
    public var radius: Float = 0
    /// Specifies the amount of the distortion, 0 being no-change.
    public var scale: Float = 0

    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "pinchDistortion")
    }

    override public var parameters: [String: Any] {
        ["center": MTIVector(value: center),
         "radius": radius,
         "scale": scale]
    }

    override public static func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        MTIAlphaTypeHandlingRule.passthrough
    }
}
