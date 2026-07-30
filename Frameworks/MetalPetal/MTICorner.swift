//
//  MTICorner.swift
//  Pods
//
//  Created by YuAo on 2021/4/28.
//

import Foundation

extension MTICornerRadius: @retroactive Equatable {
    public static func == (lhs: MTICornerRadius, rhs: MTICornerRadius) -> Bool {
        lhs.topLeft == rhs.topLeft &&
            lhs.topRight == rhs.topRight &&
            lhs.bottomLeft == rhs.bottomLeft &&
            lhs.bottomRight == rhs.bottomRight
    }
}

extension MTICornerRadius: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(topLeft)
        hasher.combine(topRight)
        hasher.combine(bottomLeft)
        hasher.combine(bottomRight)
    }
}
