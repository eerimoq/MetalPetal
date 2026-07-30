//
//  MTIRenderCommand.swift
//  Pods
//
//  Created by Yu Ao on 26/11/2017.
//

import Foundation

public final class MTIRenderCommand: NSObject, NSCopying {
    public let kernel: MTIRenderPipelineKernel
    public let geometry: MTIGeometry
    public let images: [MTIImage]
    public let parameters: [String: Any]

    public init(
        kernel: MTIRenderPipelineKernel,
        geometry: MTIGeometry,
        images: [MTIImage],
        parameters: [String: Any]
    ) {
        assert(kernel.alphaTypeHandlingRule._canHandleAlphaTypes(in: images))
        self.kernel = kernel
        self.geometry = geometry.copy(with: nil) as! MTIGeometry
        self.images = images
        self.parameters = parameters
        super.init()
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }
}
