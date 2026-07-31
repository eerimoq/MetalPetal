//
//  MTIHexagonalBokehBlurFilter.swift
//  MetalPetal
//

import Foundation
import Metal
import simd

/// An implementation of lens blur (bokeh) based on `Siggraph 2011 - Advances in Real-Time Rendering`
/// https://colinbarrebrisebois.com/2017/04/18/hexagonal-bokeh-blur-revisited/
public final class MTIHexagonalBokehBlurFilter: MTIFilter {
    public init() {}

    public var inputImage: MTIImage?
    public var inputMask: MTIMask?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var radius: Float = 0
    public var brightness: Float = 0
    public var angle: Float = 0

    private static let prepassKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "hexagonalBokehBlurPre")
    )

    private static let alphaPassKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "hexagonalBokehBlurAlpha"),
        vertexDescriptor: nil,
        colorAttachmentCount: 2,
        alphaTypeHandlingRule: .general
    )

    private static let bravoCharliePassKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "hexagonalBokehBlurBravoCharlie")
    )

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        if radius == 0 {
            return inputImage
        }
        let mask = inputMask ?? MTIMask(content: MTIImage.white, component: .red, mode: .normal)
        var deltas: [MTIVector] = []
        for i in 0 ..< 3 {
            let a = angle + Float(i) * Float.pi * 2.0 / 3.0
            deltas.append(MTIVector(value: simd_make_float2(radius * sin(a) / Float(inputImage.size.width),
                                                            radius * cos(a) / Float(inputImage.size.height))))
        }
        let power = powf(10, min(max(brightness, -1), 1))
        let usesOneMinusMaskValue = mask.mode == .oneMinusMaskValue
        let dimensions = MTITextureDimensions(cgSize: inputImage.size)
        let prepassOutputImage = MTIHexagonalBokehBlurFilter.prepassKernel.apply(
            to: [inputImage, mask.content],
            parameters: ["power": power,
                         "maskComponent": Int32(mask.component.rawValue),
                         "usesOneMinusMaskValue": usesOneMinusMaskValue],
            outputDimensions: dimensions,
            outputPixelFormat: .rgba16Float
        )
        let alphaOutputs = MTIHexagonalBokehBlurFilter.alphaPassKernel.apply(
            to: [prepassOutputImage.withSamplerDescriptor(inputImage.samplerDescriptor)],
            parameters: ["delta0": deltas[0],
                         "delta1": deltas[1]],
            outputDescriptors: [
                MTIRenderPassOutputDescriptor(dimensions: dimensions, pixelFormat: .rgba16Float),
                MTIRenderPassOutputDescriptor(dimensions: dimensions, pixelFormat: .rgba16Float),
            ]
        )
        return MTIHexagonalBokehBlurFilter.bravoCharliePassKernel.apply(
            to: [alphaOutputs[0].withSamplerDescriptor(inputImage.samplerDescriptor),
                 alphaOutputs[1].withSamplerDescriptor(inputImage.samplerDescriptor)],
            parameters: ["delta0": deltas[1],
                         "delta1": deltas[2],
                         "power": Float(1.0) / power],
            outputDimensions: dimensions,
            outputPixelFormat: outputPixelFormat
        )
    }
}
