//
//  MTITextureDimensions.swift
//  MetalPetal
//
//  Created by Yu Ao on 11/10/2017.
//

import CoreGraphics
import Foundation

public struct MTITextureDimensions: Equatable {
    public var width: Int
    public var height: Int
    public var depth: Int

    public init(width: Int, height: Int, depth: Int = 1) {
        self.width = width
        self.height = height
        self.depth = depth
    }

    public init(cgSize size: CGSize) {
        self.init(width: Int(size.width), height: Int(size.height), depth: 1)
    }
}
