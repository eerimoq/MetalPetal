//
//  MTITextureDimensions.swift
//  MetalPetal
//
//  Created by Yu Ao on 11/10/2017.
//

import CoreGraphics
import Foundation

public struct MTITextureDimensions: Equatable {
    public var width: UInt
    public var height: UInt
    public var depth: UInt

    public init(width: UInt, height: UInt, depth: UInt) {
        self.width = width
        self.height = height
        self.depth = depth
    }

    public init(cgSize size: CGSize) {
        self.init(width: UInt(size.width), height: UInt(size.height), depth: 1)
    }

    public func isEqual(to other: MTITextureDimensions) -> Bool {
        width == other.width && height == other.height && depth == other.depth
    }
}

public extension MTITextureDimensions {
    init(width: Int, height: Int, depth: Int = 1) {
        self.init(width: UInt(width), height: UInt(height), depth: UInt(depth))
    }
}
