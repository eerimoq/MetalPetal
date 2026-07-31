//
//  MTIRenderCommand.swift
//  Pods
//
//  Created by Yu Ao on 26/11/2017.
//

import Foundation

public final class MTIRenderCommand {
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
        self.kernel = kernel
        self.geometry = geometry
        self.images = images
        self.parameters = parameters
    }
}
