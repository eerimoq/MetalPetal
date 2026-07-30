//
//  MTICropRegion.swift
//  MetalPetal
//
//  Created by YuAo on 2021/2/1.
//

import CoreGraphics
import Foundation

public enum MTICropRegionUnit: UInt {
    case pixel
    case percentage
}

public struct MTICropRegion {
    public var bounds: CGRect
    public var unit: MTICropRegionUnit

    public init(bounds: CGRect, unit: MTICropRegionUnit) {
        self.bounds = bounds
        self.unit = unit
    }
}

public extension MTICropRegion {
    static func pixel(_ rect: CGRect) -> MTICropRegion {
        MTICropRegion(bounds: rect, unit: .pixel)
    }

    static func fractional(_ rect: CGRect) -> MTICropRegion {
        MTICropRegion(bounds: rect, unit: .percentage)
    }
}
