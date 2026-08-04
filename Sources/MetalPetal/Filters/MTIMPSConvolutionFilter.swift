//
//  MTIMPSConvolutionFilter.swift
//  MetalPetal
//

import Foundation
import Metal
import MetalPerformanceShaders
import os

private struct MTIMPSImageConvolutionSettings: Hashable {
    let kernelWidth: Int
    let kernelHeight: Int
    let weights: [Float]

    init(kernelWidth: Int, kernelHeight: Int, weights: UnsafePointer<Float>) {
        self.kernelWidth = kernelWidth
        self.kernelHeight = kernelHeight
        self.weights = Array(UnsafeBufferPointer(start: weights, count: kernelWidth * kernelHeight))
    }
}

public final class MTIMPSConvolutionFilter: MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    /// The bias is a value to be added to convolved pixel before it is converted back to the storage
    /// format. It can be used to convert negative values into a representable range for a unsigned
    /// MTLPixelFormat. For example, many edge detection filters produce results in the range [-k,k].
    /// By scaling the filter weights by 0.5/k and adding 0.5, the results will be in range [0,1]
    /// suitable for use with unorm formats. It can be used in combination with renormalization of the
    /// filter weights to do video ranging as part of the convolution effect. It can also just be used
    /// to increase the brightness of the image.
    ///
    /// Default value is 0.0f.
    public var bias: Float = 0
    private let kernel: MTIMPSKernel
    private static var kernels: [MTIMPSImageConvolutionSettings: MTIMPSKernel] = [:]
    private static let kernelsLock = OSAllocatedUnfairLock()

    public init(kernelWidth: Int, kernelHeight: Int, weights kernelWeights: UnsafePointer<Float>) {
        let settings = MTIMPSImageConvolutionSettings(
            kernelWidth: Int(kernelWidth),
            kernelHeight: Int(kernelHeight),
            weights: kernelWeights
        )
        kernel = MTIMPSConvolutionFilter.kernel(settings: settings)
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return kernel.apply(toInputImages: [inputImage],
                            parameters: ["bias": bias],
                            outputTextureDimensions: MTITextureDimensions(cgSize: inputImage.size),
                            outputPixelFormat: outputPixelFormat)
    }

    private static func kernel(settings: MTIMPSImageConvolutionSettings) -> MTIMPSKernel {
        kernelsLock.lock()
        defer {
            kernelsLock.unlock()
        }
        if let kernel = kernels[settings] {
            return kernel
        }
        let kernel = MTIMPSKernel(builder: { device in
            settings.weights.withUnsafeBufferPointer { buffer in
                MPSImageConvolution(
                    device: device,
                    kernelWidth: settings.kernelWidth,
                    kernelHeight: settings.kernelHeight,
                    weights: buffer.baseAddress!
                )
            }
        })
        kernels[settings] = kernel
        return kernel
    }
}
