//
//  MTIRenderCommand.swift
//  Pods
//
//  Created by Yu Ao on 26/11/2017.
//

import Foundation

public struct MTIRenderCommand {
    public let kernel: MTIRenderPipelineKernel
    public let geometry: MTIGeometry
    public let images: [MTIImage]
    public let parameters: [String: MTIFunctionArgumentValue]

    public init(kernel: MTIRenderPipelineKernel,
                geometry: MTIGeometry,
                images: [MTIImage],
                parameters: [String: MTIFunctionArgumentValue])
    {
        self.kernel = kernel
        self.geometry = geometry
        self.images = images
        self.parameters = parameters
    }
}
