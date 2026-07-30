//
//  MTIColor.swift
//  MetalPetal
//
//  Created by Yu Ao on 10/10/2017.
//

import Foundation
import simd

public enum MTIColorComponent: Int {
    case red
    case green
    case blue
    case alpha
}

public struct MTIColor: Hashable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public func toFloat4() -> simd_float4 {
        simd_make_float4(red, green, blue, alpha)
    }

    public static let white = MTIColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let black = MTIColor(red: 0, green: 0, blue: 0, alpha: 1)
    public static let clear = MTIColor(red: 0, green: 0, blue: 0, alpha: 0)
}

// MTIGrayColorTransform_ITU_R_601
public let MTIGrayColorTransformDefault = simd_float3(0.299, 0.587, 0.114)
// 0.299, 0.587, 0.114
public let MTIGrayColorTransform_ITU_R_601 = simd_float3(0.299, 0.587, 0.114)
// 0.2126, 0.7152, 0.0722
public let MTIGrayColorTransform_ITU_R_709 = simd_float3(0.2126, 0.7152, 0.0722)
