//
//  MTIRenderPipeline.swift
//  MetalPetal
//
//  Created by YuAo on 30/06/2017.
//

import Foundation
import Metal

public final class MTIRenderPipeline: NSObject, NSCopying {
    public let state: MTLRenderPipelineState

    public let reflection: MTLRenderPipelineReflection

    public init(state: MTLRenderPipelineState, reflection: MTLRenderPipelineReflection) {
        self.state = state
        self.reflection = reflection
        super.init()
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }
}
