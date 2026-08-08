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

public struct MTIMask: Hashable {
    public let content: MTIImage
    public let component: MTIColorComponent
    public let mode: MTIMaskMode

    public init(content: MTIImage, component: MTIColorComponent, mode: MTIMaskMode) {
        self.content = content
        self.component = component
        self.mode = mode
    }

    public init(content: MTIImage) {
        self.init(content: content, component: .red, mode: .normal)
    }
}
