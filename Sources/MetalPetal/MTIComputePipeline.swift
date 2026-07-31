//
//  MTIComputePipeline.swift
//  MetalPetal
//
//  Created by YuAo on 27/07/2017.
//

import Foundation
import Metal

public final class MTIComputePipeline {
    public let state: MTLComputePipelineState
    public let reflection: MTLComputePipelineReflection

    public init(state: MTLComputePipelineState, reflection: MTLComputePipelineReflection) {
        self.state = state
        self.reflection = reflection
    }
}
