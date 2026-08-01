//
//  MTIMPSSobelFilter.swift
//  MetalPetal
//

import Foundation
import Metal
import MetalPerformanceShaders
import simd

public enum MTIMPSSobelColorMode {
    case auto
    case grayscale
    case grayscaleInverted
}

public final class MTIMPSSobelFilter: MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public private(set) var grayColorTransform: simd_float3
    public var colorMode: MTIMPSSobelColorMode = .auto
    private let kernel: MTIMPSKernel

    public convenience init() {
        self.init(grayColorTransform: MTIGrayColorTransformDefault)
    }

    public init(grayColorTransform: simd_float3) {
        self.grayColorTransform = grayColorTransform
        kernel = MTIMPSKernel(builder: { device in
            let values: [Float] = [grayColorTransform.x, grayColorTransform.y, grayColorTransform.z]
            let k = MPSImageSobel(device: device, linearGrayColorTransform: values)
            k.edgeMode = .clamp
            return k
        })
    }

    private static let rToMonochromeKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "rToMonochrome"),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: .general
    )

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        let dimensions = MTITextureDimensions(cgSize: inputImage.size)
        switch colorMode {
        case .auto:
            return kernel.apply(toInputImages: [inputImage],
                                parameters: [:],
                                outputTextureDimensions: dimensions,
                                outputPixelFormat: outputPixelFormat)
        case .grayscale, .grayscaleInverted:
            let sobelImage = kernel.apply(toInputImages: [inputImage],
                                          parameters: [:],
                                          outputTextureDimensions: dimensions,
                                          outputPixelFormat: .r8Unorm)
            return MTIMPSSobelFilter.rToMonochromeKernel.apply(
                to: [sobelImage],
                parameters: ["invert": colorMode == .grayscaleInverted,
                             "convertSRGBToLinear": false],
                outputDimensions: dimensions,
                outputPixelFormat: outputPixelFormat
            )
        }
    }
}
