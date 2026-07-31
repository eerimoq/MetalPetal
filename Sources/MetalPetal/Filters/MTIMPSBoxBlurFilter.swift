//
//  MTIMPSBoxBlurFilter.swift
//  MetalPetal
//

import Foundation
import Metal
import MetalPerformanceShaders
import os
import simd

public final class MTIMPSBoxBlurFilter: MTIUnaryFilter {
    public init() {}

    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var size: simd_int2 = .init(0, 0)
    private static var kernels: [SIMD2<Int32>: MTIMPSKernel] = [:]
    private static let kernelsLock = OSAllocatedUnfairLock()

    private static func kernel(size: simd_int2) -> MTIMPSKernel {
        kernelsLock.lock()
        defer {
            kernelsLock.unlock()
        }
        if let kernel = kernels[size] {
            return kernel
        }
        let kernel = MTIMPSKernel(builder: { device in
            let k = MPSImageBox(device: device, kernelWidth: Int(size.x), kernelHeight: Int(size.y))
            k.edgeMode = .clamp
            return k
        })
        kernels[size] = kernel
        return kernel
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        if size.x <= 1 || size.y <= 1 {
            return inputImage
        }
        var size = size
        size.x = size.x + (size.x + 1) % 2
        size.y = size.y + (size.y + 1) % 2
        return MTIMPSBoxBlurFilter.kernel(size: size).apply(
            toInputImages: [inputImage],
            parameters: [:],
            outputTextureDimensions: MTITextureDimensions(cgSize: inputImage
                .size),
            outputPixelFormat: outputPixelFormat
        )
    }
}
