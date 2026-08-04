//
//  MTIMPSGaussianBlurFilter.swift
//  MetalPetal
//

import Foundation
import Metal
import MetalPerformanceShaders
import os

public final class MTIMPSGaussianBlurFilter: MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var radius: Float = 0
    private static var kernels: [Int: MTIMPSKernel] = [:]
    private static let kernelsLock = OSAllocatedUnfairLock()

    public init() {}

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        let radius = ceil(radius)
        if radius <= 0 {
            return inputImage
        }
        return MTIMPSGaussianBlurFilter.kernel(radius: Int(radius)).apply(
            toInputImages: [inputImage],
            parameters: [:],
            outputTextureDimensions: MTITextureDimensions(cgSize: inputImage.size),
            outputPixelFormat: outputPixelFormat
        )
    }

    private static func kernel(radius: Int) -> MTIMPSKernel {
        kernelsLock.lock()
        defer {
            kernelsLock.unlock()
        }
        if let kernel = kernels[radius] {
            return kernel
        }
        // ceil(sqrt(-log(0.01)*2)*sigma) ~ ceil(3.7*sigma)
        let sigma = Float(radius)
        let kernel = MTIMPSKernel(builder: { device in
            let k = MPSImageGaussianBlur(device: device, sigma: sigma)
            k.edgeMode = .clamp
            return k
        })
        kernels[radius] = kernel
        return kernel
    }
}
