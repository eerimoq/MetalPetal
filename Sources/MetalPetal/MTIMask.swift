//
//  MTIMask.swift
//  MetalPetal
//
//  Created by Yu Ao on 14/11/2017.
//

import Foundation

public enum MTIMaskMode: Int {
    case normal
    case oneMinusMaskValue
}

public final class MTIMask: Hashable {
    public let content: MTIImage
    public let component: MTIColorComponent
    public let mode: MTIMaskMode

    public init(content: MTIImage, component: MTIColorComponent, mode: MTIMaskMode) {
        self.content = content
        self.component = component
        self.mode = mode
    }

    public convenience init(content: MTIImage) {
        self.init(content: content, component: .red, mode: .normal)
    }

    public static func == (lhs: MTIMask, rhs: MTIMask) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
