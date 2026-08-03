//
//  MTICrtFilter.swift
//

import Foundation
import Metal

public final class MTICrtFilter: MTIFilter {
    public var inputImage: MTIImage?
    public var barrelStrength: Float = 0.1
    public var outputPixelFormat: MTLPixelFormat = .unspecified

    public init() {}

    private static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .init(name: "passthroughVertex"),
        fragmentFunctionDescriptor: .init(name: "crt")
    )

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        let width = Float(inputImage.extent.width)
        let height = Float(inputImage.extent.height)
        return MTICrtFilter.kernel.apply(
            to: [inputImage],
            parameters: [
                "inputWidth": .float(width),
                "inputHeight": .float(height),
                "barrelStrength": .float(barrelStrength),
            ],
            outputDimensions: MTITextureDimensions(cgSize: inputImage.size),
            outputPixelFormat: outputPixelFormat
        )
    }
}
