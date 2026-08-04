//
//  MTIBlendFilter.swift
//  MetalPetal
//

import Foundation
import Metal
import os

public final class MTIBlendFilter: MTIFilter {
    public let blendMode: MTIBlendMode
    public var inputBackgroundImage: MTIImage?
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    /// Specifies the intensity (in the range [0, 1]) of the operation.
    public var intensity: Float = 1.0
    /// Specifies the alpha type of output image. If `.alphaIsOne` is assigned, the alpha channel of
    /// the output image will be set to 1. The default value for this property is `.nonPremultiplied`.
    public var outputAlphaType: MTIAlphaType = .nonPremultiplied
    private static var kernels: [KernelKey: MTIRenderPipelineKernel] = [:]
    private static let kernelsLock = OSAllocatedUnfairLock()

    public init(blendMode mode: MTIBlendMode) {
        blendMode = mode
    }

    public var outputImage: MTIImage? {
        guard let inputBackgroundImage, let inputImage else {
            return nil
        }
        let kernel = MTIBlendFilter.kernel(blendMode: blendMode,
                                           backdropAlphaType: inputBackgroundImage.alphaType,
                                           sourceAlphaType: inputImage.alphaType,
                                           outputAlphaType: outputAlphaType)
        return kernel.apply(to: [inputBackgroundImage, inputImage],
                            parameters: ["intensity": .float(intensity)],
                            outputDimensions: .init(cgSize: inputBackgroundImage.size),
                            outputPixelFormat: outputPixelFormat)
    }

    private struct KernelKey: Hashable {
        let mode: MTIBlendMode
        let sourceHasPremultipliedAlpha: Bool
        let backdropHasPremultipliedAlpha: Bool
        let outputsPremultipliedAlpha: Bool
        let outputsOpaqueImage: Bool

        init(
            mode: MTIBlendMode,
            backdropAlphaType: MTIAlphaType,
            sourceAlphaType: MTIAlphaType,
            outputAlphaType: MTIAlphaType
        ) {
            self.mode = mode
            sourceHasPremultipliedAlpha = sourceAlphaType == .premultiplied
            backdropHasPremultipliedAlpha = backdropAlphaType == .premultiplied
            outputsPremultipliedAlpha = outputAlphaType == .premultiplied
            outputsOpaqueImage = outputAlphaType == .alphaIsOne
        }
    }

    private static func kernel(blendMode mode: MTIBlendMode,
                               backdropAlphaType: MTIAlphaType,
                               sourceAlphaType: MTIAlphaType,
                               outputAlphaType: MTIAlphaType) -> MTIRenderPipelineKernel
    {
        let key = KernelKey(
            mode: mode,
            backdropAlphaType: backdropAlphaType,
            sourceAlphaType: sourceAlphaType,
            outputAlphaType: outputAlphaType
        )
        kernelsLock.lock()
        defer {
            kernelsLock.unlock()
        }
        if let kernel = kernels[key] {
            return kernel
        }
        let constantValues = MTLFunctionConstantValues()
        var sourceHasPremultipliedAlpha = key.sourceHasPremultipliedAlpha
        var backdropHasPremultipliedAlpha = key.backdropHasPremultipliedAlpha
        var outputsPremultipliedAlpha = key.outputsPremultipliedAlpha
        var outputsOpaqueImage = key.outputsOpaqueImage
        constantValues.setConstantValue(
            &sourceHasPremultipliedAlpha,
            type: .bool,
            withName: "metalpetal::blend_filter_source_has_premultiplied_alpha"
        )
        constantValues.setConstantValue(
            &backdropHasPremultipliedAlpha,
            type: .bool,
            withName: "metalpetal::blend_filter_backdrop_has_premultiplied_alpha"
        )
        constantValues.setConstantValue(
            &outputsPremultipliedAlpha,
            type: .bool,
            withName: "metalpetal::blend_filter_outputs_premultiplied_alpha"
        )
        constantValues.setConstantValue(
            &outputsOpaqueImage,
            type: .bool,
            withName: "metalpetal::blend_filter_outputs_opaque_image"
        )
        let fragmentFunctionDescriptor = MTIBlendModes.functionDescriptors(for: mode)!
            .forBlendFilter
            .withConstantValues(constantValues)
        let rule = MTIAlphaTypeHandlingRule(
            acceptableAlphaTypes: [.premultiplied, .nonPremultiplied, .alphaIsOne],
            outputAlphaType: outputAlphaType
        )
        let kernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .init(name: MTIFilterPassthroughVertexFunctionName),
            fragmentFunctionDescriptor: fragmentFunctionDescriptor,
            vertexDescriptor: nil,
            colorAttachmentCount: 1,
            alphaTypeHandlingRule: rule
        )
        kernels[key] = kernel
        return kernel
    }
}
