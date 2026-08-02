//
//  MTIPixellateFilter.swift
//  Pods
//
//  Created by Yu Ao on 08/01/2018.
//

import CoreGraphics
import Foundation

public final class MTIPixellateFilter: MTIUnaryImageRenderingFilter {
    /// Specifies the scale of the operation, i.e. the size for the pixels in the resulting image.
    public var scale: simd_float2 = simd_make_float2(16, 16)

    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "pixellate")
    }

    override public var parameters: [String: MTIFunctionArgumentValue] {
        ["scale": .simd(.float2(scale))]
    }

    override public static func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        .passthrough
    }
}
