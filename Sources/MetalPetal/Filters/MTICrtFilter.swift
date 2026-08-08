//
//  MTICrtFilter.swift
//

import Foundation
import Metal

public final class MTICrtFilter: MTIUnaryImageRenderingFilter {
    public var barrelStrength: Float = 0.1

    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "crt")
    }

    override public var parameters: [String: MTIFunctionArgumentValue] {
        [
            "inputWidth": .float(Float(inputImage?.extent.width ?? 0)),
            "inputHeight": .float(Float(inputImage?.extent.height ?? 0)),
            "barrelStrength": .float(barrelStrength),
        ]
    }
}
