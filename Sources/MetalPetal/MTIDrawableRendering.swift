//
//  MTIDrawableRendering.swift
//  Pods
//
//  Created by YuAo on 01/07/2017.
//

import Foundation
import Metal
import MetalKit

public protocol MTIDrawableProvider: AnyObject {
    func drawable(for request: MTIDrawableRenderingRequest) -> MTLDrawable?
    func renderPassDescriptor(for request: MTIDrawableRenderingRequest) -> MTLRenderPassDescriptor?
}

public enum MTIDrawableRenderingResizingMode {
    case scale
    case aspect
    case aspectFill
}

public struct MTIDrawableRenderingRequest {
    public weak var drawableProvider: MTIDrawableProvider?
    public let resizingMode: MTIDrawableRenderingResizingMode

    public init(drawableProvider: MTIDrawableProvider, resizingMode: MTIDrawableRenderingResizingMode) {
        self.drawableProvider = drawableProvider
        self.resizingMode = resizingMode
    }
}

extension MTKView: MTIDrawableProvider {
    public func drawable(for _: MTIDrawableRenderingRequest) -> MTLDrawable? {
        currentDrawable
    }

    public func renderPassDescriptor(for _: MTIDrawableRenderingRequest) -> MTLRenderPassDescriptor? {
        currentRenderPassDescriptor
    }
}
