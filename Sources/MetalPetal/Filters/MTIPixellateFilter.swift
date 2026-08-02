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
    public var scale: CGSize = .init(width: 16, height: 16)

    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "pixellate")
    }

    override public var parameters: [String: MTIFunctionArgumentValue] {
        let value = CGSize(width: max(scale.width, 1), height: max(scale.height, 1))
        return ["scale": .vector(MTIVector(value: value))]
    }

    override public static func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        MTIAlphaTypeHandlingRule.passthrough
    }
}
