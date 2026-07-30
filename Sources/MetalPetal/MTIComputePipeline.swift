//
//  MTIComputePipeline.swift
//  MetalPetal
//
//  Created by YuAo on 27/07/2017.
//

import Foundation
import Metal

public final class MTIComputePipeline: NSObject, NSCopying {
    public let state: MTLComputePipelineState

    public let reflection: MTLComputePipelineReflection

    public init(state: MTLComputePipelineState, reflection: MTLComputePipelineReflection) {
        self.state = state
        self.reflection = reflection
        super.init()
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }
}
