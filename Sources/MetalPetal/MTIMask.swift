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

public final class MTIMask: NSObject, NSCopying {
    public let content: MTIImage
    public let component: MTIColorComponent
    public let mode: MTIMaskMode

    public init(content: MTIImage, component: MTIColorComponent, mode: MTIMaskMode) {
        self.content = content
        self.component = component
        self.mode = mode
        super.init()
    }

    public convenience init(content: MTIImage) {
        self.init(content: content, component: .red, mode: .normal)
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }
}
