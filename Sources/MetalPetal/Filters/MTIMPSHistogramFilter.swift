//
//  MTIMPSHistogramFilter.swift
//  MetalPetal
//

import CoreGraphics
import Foundation
import Metal
import MetalPerformanceShaders
import simd

public struct MTIHistogramType: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let luminance = MTIHistogramType(rawValue: 1 << 0)
    public static let rgb = MTIHistogramType(rawValue: 1 << 1)
}

private final class MTIMPSHistogramRecipe: MTIImagePromise {
    let inputImage: MTIImage
    let histogramInfo: MPSImageHistogramInfo
    let sourceRegion: MTLRegion
    let dimensions: MTITextureDimensions
    let alphaType: MTIAlphaType
    var dependencies: [MTIImage] {
        [inputImage]
    }

    init(inputImage: MTIImage, histogramInfo: MPSImageHistogramInfo, sourceRegion: MTLRegion) {
        self.inputImage = inputImage
        dimensions = MTITextureDimensions(cgSize: CGSize(
            width: Int(histogramInfo.numberOfHistogramEntries),
            height: 4
        ))
        self.histogramInfo = histogramInfo
        self.sourceRegion = sourceRegion
        alphaType = .alphaIsOne
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        guard renderingContext.context.isMetalPerformanceShadersSupported else {
            throw MTIError(code: .mpsKernelNotSupported, message: "MTIErrorMPSKernelNotSupported")
        }
        let inputTexture = renderingContext.resolvedTexture(for: inputImage)
        var info = histogramInfo
        let kernel = MPSImageHistogram(device: renderingContext.context.device, histogramInfo: &info)
        kernel.clipRectSource = sourceRegion
        kernel.zeroHistogram = true
        let bytesPerComponent = 4
        let bufferSize = dimensions.width * dimensions.height * bytesPerComponent
        guard let buffer = renderingContext.context.device.makeBuffer(
            length: bufferSize,
            options: .storageModePrivate
        ) else {
            throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
        }
        kernel.encode(
            to: renderingContext.commandBuffer,
            sourceTexture: inputTexture,
            histogram: buffer,
            histogramOffset: 0
        )
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Uint,
            width: dimensions.width,
            height: dimensions.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.storageMode = .private
        guard let texture = buffer.makeTexture(
            descriptor: textureDescriptor,
            offset: 0,
            bytesPerRow: Int(histogramInfo.numberOfHistogramEntries) * bytesPerComponent
        ) else {
            throw MTIError(code: .failedToCreateTexture, message: "MTIErrorFailedToCreateTexture")
        }
        return renderingContext.context.makeRenderTarget(texture: texture)
    }

    func updatingDependencies(_ dependencies: [MTIImage]) -> Self {
        MTIMPSHistogramRecipe(
            inputImage: dependencies[0],
            histogramInfo: histogramInfo,
            sourceRegion: sourceRegion
        ) as! Self
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .processor, content: "MPSHistogram")
    }
}

public final class MTIMPSHistogramFilter: MTIFilter {
    public init() {}

    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .r32Uint
    /// Unimplemented
    public var scaleFactor: Float = 0
    /// Unimplemented
    public var type: MTIHistogramType = []

    private let histogramInfo: MPSImageHistogramInfo = {
        var info = MPSImageHistogramInfo()
        info.numberOfHistogramEntries = 256
        info.histogramForAlpha = true
        info.minPixelValue = simd_float4(0, 0, 0, 0)
        info.maxPixelValue = simd_float4(1, 1, 1, 1)
        return info
    }()

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        // handle histogram type and scale
        let recipe = MTIMPSHistogramRecipe(inputImage: inputImage,
                                           histogramInfo: histogramInfo,
                                           sourceRegion: MTLRegionMake2D(
                                               0,
                                               0,
                                               Int(inputImage.size.width),
                                               Int(inputImage.size.height)
                                           ))
        return MTIImage(promise: recipe)
    }
}

public final class MTIHistogramDisplayFilter: MTIUnaryFilter {
    public init() {}

    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var outputSize: CGSize = .zero

    private static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: .init(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: .init(name: "histogramDisplay"),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: .general
    )

    private static let histogramMaxKernel = MTIComputePipelineKernel(
        computeFunctionDescriptor: MTIFunctionDescriptor(name: "histogramDisplayFindMax")
    )

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        var outputSize = outputSize
        if outputSize.width <= 0 {
            outputSize.width = inputImage.size.width
        }
        if outputSize.height <= 0 {
            outputSize.height = inputImage.size.width
        }
        let maxValueImage = MTIHistogramDisplayFilter.histogramMaxKernel.apply(
            toInputImages: [inputImage],
            parameters: [:],
            outputTextureDimensions: MTITextureDimensions(cgSize: CGSize(width: 1, height: 1)),
            outputPixelFormat: .rgba32Uint
        )
        return MTIHistogramDisplayFilter.kernel.apply(
            to: [inputImage, maxValueImage],
            parameters: [:],
            outputDimensions: MTITextureDimensions(cgSize: outputSize),
            outputPixelFormat: outputPixelFormat
        )
    }
}
