//
//  MTIGeometry.swift
//  MetalPetal
//
//  Created by Yu Ao on 2018/5/6.
//

import Foundation
import Metal

public protocol MTIGeometryRenderingContext {
    var renderPipeline: MTIRenderPipeline { get }
    var device: MTLDevice { get }
}

public protocol MTIGeometry {
    func encodeDrawCall(
        with commandEncoder: MTLRenderCommandEncoder,
        context: MTIGeometryRenderingContext
    )
}

extension MTIRenderPipeline: MTIGeometryRenderingContext {
    public var renderPipeline: MTIRenderPipeline {
        self
    }

    public var device: MTLDevice {
        state.device
    }
}
