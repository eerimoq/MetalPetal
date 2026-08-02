//
//  MTIVibranceFilter.swift
//  MetalPetal
//
//  Created by 杨乃川 on 2017/11/6.
//

import Foundation

public final class MTIVibranceFilter: MTIUnaryImageRenderingFilter {
    /// Specifies the scale of the operation in the range of -1 to 1, with 0 being no-change.
    public var amount: Float = 0
    public var avoidsSaturatingSkinTones: Bool = false
    public var grayColorTransform: simd_float3 = MTIGrayColorTransformDefault

    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "vibranceAdjust")
    }

    override public var parameters: [String: MTIFunctionArgumentValue] {
        let vector = simd_float4(
            3 * amount,
            -9.0 / 2.0 * amount * amount - 3.0 / 2.0 * amount,
            9.0 / 2.0 * amount * amount * amount - amount / 2.0,
            -9.0 / 2.0 * amount * amount * amount + 9.0 / 2.0 * amount * amount - amount
        )
        return ["amount": .float(amount),
                "vibranceVector": .simd(.float4(vector)),
                "avoidsSaturatingSkinTones": .bool(avoidsSaturatingSkinTones),
                "grayColorTransform": .simd(.float3(grayColorTransform))]
    }

    override public static func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        .general
    }
}
