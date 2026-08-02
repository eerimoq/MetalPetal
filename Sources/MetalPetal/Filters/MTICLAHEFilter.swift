//
//  MTICLAHEFilter.swift
//  MetalPetal
//

import CoreGraphics
import Foundation
import Metal
import MetalPerformanceShaders
import simd

public struct MTICLAHESize {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Performs Contrast Limited Adaptive Histogram Equalization. https://github.com/YuAo/Accelerated-CLAHE
public final class MTICLAHEFilter: MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var clipLimit: Float = 2.0
    public var tileGridSize = MTICLAHESize(width: 8, height: 8)
    private static let lutGeneratorKernel = MTICLAHELUTKernel()
    private static let rgb2LightnessKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "CLAHERGB2Lightness"),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: MTIAlphaTypeHandlingRule(
            acceptableAlphaTypes: [.nonPremultiplied, .alphaIsOne],
            outputAlphaType: .alphaIsOne
        )
    )
    private static let claheLookupKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "CLAHEColorLookup")
    )

    public init() {}

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        let samplerDescriptor = inputImage.samplerDescriptor.makeMTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .mirrorRepeat
        samplerDescriptor.tAddressMode = .mirrorRepeat
        samplerDescriptor.rAddressMode = .mirrorRepeat
        let inputImageForLUT = inputImage.withSamplerDescriptor(samplerDescriptor.makeMTISamplerDescriptor())
        let dY = (tileGridSize.height - (Int(inputImage.size.height) % tileGridSize.height)) % tileGridSize
            .height
        let dX = (tileGridSize.width - (Int(inputImage.size.width) % tileGridSize.width)) % tileGridSize.width
        let lightnessTextureDimensions = MTITextureDimensions(cgSize: CGSize(
            width: inputImage.size.width + CGFloat(dX),
            height: inputImage.size.height + CGFloat(dY)
        ))
        let lightnessImageScale = simd_make_float2(
            Float((inputImage.size.width + CGFloat(dX)) / inputImage.size.width),
            Float((inputImage.size.height + CGFloat(dY)) / inputImage.size.height)
        )
        let lightnessImage = MTICLAHEFilter.rgb2LightnessKernel.apply(
            to: [inputImageForLUT],
            parameters: ["scale": .simd(.float2(lightnessImageScale))],
            outputDimensions: lightnessTextureDimensions,
            outputPixelFormat: .r8Unorm
        )
        let lutImage = MTIImage(promise: MTICLAHELUTRecipe(kernel: MTICLAHEFilter.lutGeneratorKernel,
                                                           inputLightnessImage: lightnessImage,
                                                           clipLimit: clipLimit,
                                                           tileGridSize: tileGridSize))
        let tileGridSizeVector = simd_make_float2(Float(tileGridSize.width), Float(tileGridSize.height))
        return MTICLAHEFilter.claheLookupKernel.apply(
            to: [inputImage, lutImage],
            parameters: ["tileGridSize": .simd(.float2(tileGridSizeVector))],
            outputDimensions: MTITextureDimensions(cgSize: inputImage
                .size),
            outputPixelFormat: outputPixelFormat
        )
    }
}

private let MTICLAHEHistogramBinCount = 256

private final class MTICLAHELUTKernelState {
    let histogramKernel: MPSImageHistogram
    let lutGeneratingPipeline: MTIComputePipeline

    init(histogramKernel: MPSImageHistogram, lutGeneratingPipeline: MTIComputePipeline) {
        self.histogramKernel = histogramKernel
        self.lutGeneratingPipeline = lutGeneratingPipeline
    }
}

private final class MTICLAHELUTKernel: MTIKernel {
    func makeKernelState(context: MTIContext, configuration _: MTIKernelConfiguration?) throws -> Any {
        guard context.isMetalPerformanceShadersSupported else {
            throw MTIError(code: .mpsKernelNotSupported, message: "MTIErrorMPSKernelNotSupported")
        }
        var info = MPSImageHistogramInfo()
        info.numberOfHistogramEntries = MTICLAHEHistogramBinCount
        info.minPixelValue = vector_float4(0, 0, 0, 0)
        info.maxPixelValue = vector_float4(1, 1, 1, 1)
        info.histogramForAlpha = false
        let histogram = MPSImageHistogram(device: context.device, histogramInfo: &info)
        histogram.zeroHistogram = false
        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        let computeFunction = try context.function(with: MTIFunctionDescriptor(name: "CLAHEGenerateLUT"))
        computePipelineDescriptor.computeFunction = computeFunction
        let computePipeline = try context.computePipeline(with: computePipelineDescriptor)
        return MTICLAHELUTKernelState(histogramKernel: histogram, lutGeneratingPipeline: computePipeline)
    }
}

private final class MTICLAHELUTRecipe: MTIImagePromise {
    private let kernel: MTICLAHELUTKernel
    private let inputLightnessImage: MTIImage
    private let clipLimitValue: Int
    private let tileGridSize: MTICLAHESize
    private let tileSize: MTICLAHESize
    private let numberOfLUTs: Int
    private let clipLimit: Float

    init(
        kernel: MTICLAHELUTKernel,
        inputLightnessImage: MTIImage,
        clipLimit: Float,
        tileGridSize: MTICLAHESize
    ) {
        self.kernel = kernel
        self.tileGridSize = tileGridSize
        self.inputLightnessImage = inputLightnessImage
        tileSize = MTICLAHESize(width: Int(inputLightnessImage.size.width) / tileGridSize.width,
                                height: Int(inputLightnessImage.size.height) / tileGridSize.height)
        self.clipLimit = clipLimit
        clipLimitValue = max(
            Int(clipLimit * Float(tileSize.width) * Float(tileSize.height) /
                Float(MTICLAHEHistogramBinCount)),
            1
        )
        numberOfLUTs = tileGridSize.width * tileGridSize.height
    }

    var dependencies: [MTIImage] {
        [inputLightnessImage]
    }

    var dimensions: MTITextureDimensions {
        MTITextureDimensions(width: MTICLAHEHistogramBinCount, height: numberOfLUTs, depth: 1)
    }

    var alphaType: MTIAlphaType {
        .alphaIsOne
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        let inputLightnessImageTexture = renderingContext.resolvedTexture(for: inputLightnessImage)
        guard let kernelState = try renderingContext.context
            .kernelState(for: kernel, configuration: nil) as? MTICLAHELUTKernelState
        else {
            throw MTIError(code: .mpsKernelNotSupported, message: "MTIErrorMPSKernelNotSupported")
        }
        let textureDescriptor = MTITextureDescriptor(pixelFormat: .r8Unorm,
                                                     width: Int(MTICLAHEHistogramBinCount),
                                                     height: Int(numberOfLUTs),
                                                     mipmapped: false,
                                                     usage: [.shaderWrite, .shaderRead],
                                                     resourceOptions: .storageModePrivate)
        let renderTarget = try renderingContext.context
            .makeRenderTarget(reusableTextureDescriptor: textureDescriptor)
        // May need to get a copy
        let histogramKernel = kernelState.histogramKernel
        // TO DO: Optimize buffer alloc here
        let histogramSize = histogramKernel
            .histogramSize(forSourceFormat: inputLightnessImageTexture.pixelFormat)
        guard let histogramBuffer = renderingContext.context.device.makeBuffer(
            length: histogramSize * numberOfLUTs,
            options: .storageModePrivate
        ) else {
            throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
        }
        for tileIndex in 0 ..< numberOfLUTs {
            let column = tileIndex % tileGridSize.width
            let row = tileIndex / tileGridSize.width
            histogramKernel.clipRectSource = MTLRegionMake2D(
                column * tileSize.width,
                row * tileSize.height,
                tileSize.width,
                tileSize.height
            )
            histogramKernel.encode(to: renderingContext.commandBuffer,
                                   sourceTexture: inputLightnessImageTexture,
                                   histogram: histogramBuffer,
                                   histogramOffset: tileIndex * histogramSize)
        }
        var parameters = MTICLAHELUTGeneratorInputParameters()
        parameters.histogramBins = UInt32(MTICLAHEHistogramBinCount)
        parameters.clipLimit = UInt32(clipLimitValue)
        parameters.totalPixelCountPerTile = UInt32(tileSize.width * tileSize.height)
        parameters.numberOfLUTs = UInt32(numberOfLUTs)
        guard let commandEncoder = renderingContext.commandBuffer.makeComputeCommandEncoder() else {
            throw MTIError(
                code: .failedToCreateCommandEncoder,
                message: "MTIErrorFailedToCreateCommandEncoder"
            )
        }
        commandEncoder.setComputePipelineState(kernelState.lutGeneratingPipeline.state)
        commandEncoder.setBuffer(histogramBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(
            &parameters,
            length: MemoryLayout<MTICLAHELUTGeneratorInputParameters>.size,
            index: 1
        )
        commandEncoder.setTexture(renderTarget.texture, index: 0)
        let w = kernelState.lutGeneratingPipeline.state.threadExecutionWidth
        let threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: (numberOfLUTs + w - 1) / w, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        commandEncoder.endEncoding()
        return renderTarget
    }

    func updatingDependencies(_ dependencies: [MTIImage]) -> Self {
        MTICLAHELUTRecipe(
            kernel: kernel,
            inputLightnessImage: dependencies[0],
            clipLimit: clipLimit,
            tileGridSize: tileGridSize
        ) as! Self
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .processor, content: ["clipLimit": clipLimit,
                                                                            "tileGridSize": [
                                                                                tileSize.width,
                                                                                tileSize.height,
                                                                            ]])
    }
}
