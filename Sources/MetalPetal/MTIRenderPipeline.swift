//
//  MTIRenderPipeline.swift
//  MetalPetal
//
//  Created by YuAo on 30/06/2017.
//

import Foundation
import Metal

public struct MTIRenderPipeline {
    public let state: MTLRenderPipelineState
    public let reflection: MTLRenderPipelineReflection

    public init(state: MTLRenderPipelineState, reflection: MTLRenderPipelineReflection) {
        self.state = state
        self.reflection = reflection
    }
}
