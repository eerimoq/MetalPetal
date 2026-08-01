//
//  MTICorner.swift
//  MetalPetal
//
//  Created by YuAo on 2021/4/26.
//

import Foundation
import simd

public struct MTICornerRadius: Hashable {
    public var topLeft: Float
    public var topRight: Float
    public var bottomRight: Float
    public var bottomLeft: Float

    public init(topLeft: Float, topRight: Float, bottomRight: Float, bottomLeft: Float) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public init(_ r: Float) {
        self.init(topLeft: r, topRight: r, bottomRight: r, bottomLeft: r)
    }

    public var isZero: Bool {
        topLeft == 0 && topRight == 0 && bottomLeft == 0 && bottomRight == 0
    }
}

public enum MTICornerCurve {
    /// A circular corner curve.
    case circular
    /// A continuous corner curve. This option mimics the behavior of `kCACornerCurveContinuous`.
    case continuous
}

public extension MTICornerCurve {
    /// Expansion scale factor applied to the rounded corner bounding box size when a specific corner curve is
    /// used.
    var expansionFactor: Float {
        switch self {
        case .circular:
            1.0
        case .continuous:
            1.528665
        }
    }
}

extension MTICornerRadius {
    /// The per-corner radii the shaders expect, scaled for the given curve.
    func shadingParameterValue(for curve: MTICornerCurve) -> simd_float4 {
        simd_make_float4(topLeft, topRight, bottomRight, bottomLeft) * curve.expansionFactor
    }
}
