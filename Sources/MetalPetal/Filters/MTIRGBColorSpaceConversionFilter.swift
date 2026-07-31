//
//  MTIRGBColorSpaceConversionFilter.swift
//  Pods
//
//  Created by YuAo on 2021/4/13.
//

import Foundation
import Metal
import os

public final class MTILinearToSRGBToneCurveFilter: MTIUnaryImageRenderingFilter {
    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "convertLinearRGBToSRGB")
    }

    public static func image(byProcessingImage image: MTIImage) -> MTIImage {
        self.image(byProcessingImage: image, withInputParameters: [:], outputPixelFormat: .unspecified)
    }
}

public final class MTISRGBToneCurveToLinearFilter: MTIUnaryImageRenderingFilter {
    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "convertSRGBToLinearRGB")
    }

    public static func image(byProcessingImage image: MTIImage) -> MTIImage {
        self.image(byProcessingImage: image, withInputParameters: [:], outputPixelFormat: .unspecified)
    }
}

public final class MTIITUR709RGBToLinearRGBFilter: MTIUnaryImageRenderingFilter {
    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "convertITUR709RGBToLinearRGB")
    }

    public static func image(byProcessingImage image: MTIImage) -> MTIImage {
        self.image(byProcessingImage: image, withInputParameters: [:], outputPixelFormat: .unspecified)
    }
}

public final class MTIITUR709RGBToSRGBFilter: MTIUnaryImageRenderingFilter {
    override public static func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: "convertITUR709RGBToSRGB")
    }

    public static func image(byProcessingImage image: MTIImage) -> MTIImage {
        self.image(byProcessingImage: image, withInputParameters: [:], outputPixelFormat: .unspecified)
    }
}

public enum MTIRGBColorSpace: Int {
    case linearSRGB = 0
    case sRGB = 1
    case itur709 = 2
}

public final class MTIRGBColorSpaceConversionFilter: MTIUnaryFilter {
    public init() {}

    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var inputColorSpace: MTIRGBColorSpace = .linearSRGB
    public var outputColorSpace: MTIRGBColorSpace = .linearSRGB
    public var outputAlphaType: MTIAlphaType = .nonPremultiplied

    /// The function constants fully determine the kernel, so they double as its cache key.
    private struct KernelConfiguration: Hashable {
        let inputColorSpace: Int
        let outputColorSpace: Int
        let inputHasPremultipliedAlpha: Bool
        let outputsPremultipliedAlpha: Bool
        let outputsOpaqueImage: Bool
    }

    private static var kernels: [KernelConfiguration: MTIRenderPipelineKernel] = [:]
    private static let kernelsLock = OSAllocatedUnfairLock()

    private static func kernel(inputColorSpace: MTIRGBColorSpace,
                               outputColorSpace: MTIRGBColorSpace,
                               inputAlphaType: MTIAlphaType,
                               outputAlphaType: MTIAlphaType) -> MTIRenderPipelineKernel
    {
        let configuration = KernelConfiguration(
            inputColorSpace: inputColorSpace.rawValue,
            outputColorSpace: outputColorSpace.rawValue,
            inputHasPremultipliedAlpha: inputAlphaType == .premultiplied,
            outputsPremultipliedAlpha: outputAlphaType == .premultiplied,
            outputsOpaqueImage: outputAlphaType == .alphaIsOne
        )
        kernelsLock.lock()
        defer {
            kernelsLock.unlock()
        }
        if let kernel = kernels[configuration] {
            return kernel
        }
        let constantValues = MTLFunctionConstantValues()
        var inputColorSpaceValue = Int16(configuration.inputColorSpace)
        var outputColorSpaceValue = Int16(configuration.outputColorSpace)
        var inputHasPremultipliedAlpha = configuration.inputHasPremultipliedAlpha
        var outputsPremultipliedAlpha = configuration.outputsPremultipliedAlpha
        var outputsOpaqueImage = configuration.outputsOpaqueImage
        constantValues.setConstantValue(
            &inputHasPremultipliedAlpha,
            type: .bool,
            withName: "metalpetal::rgb_color_space_conversion_input_has_premultiplied_alpha"
        )
        constantValues.setConstantValue(
            &inputColorSpaceValue,
            type: .short,
            withName: "metalpetal::rgb_color_space_conversion_input_color_space"
        )
        constantValues.setConstantValue(
            &outputColorSpaceValue,
            type: .short,
            withName: "metalpetal::rgb_color_space_conversion_output_color_space"
        )
        constantValues.setConstantValue(
            &outputsPremultipliedAlpha,
            type: .bool,
            withName: "metalpetal::rgb_color_space_conversion_outputs_premultiplied_alpha"
        )
        constantValues.setConstantValue(
            &outputsOpaqueImage,
            type: .bool,
            withName: "metalpetal::rgb_color_space_conversion_outputs_opaque_image"
        )
        let fragmentFunctionDescriptor = MTIFunctionDescriptor(
            name: "rgbColorSpaceConvert",
            constantValues: constantValues,
            libraryURL: nil
        )
        let rule = MTIAlphaTypeHandlingRule(
            acceptableAlphaTypes: [.premultiplied, .nonPremultiplied, .alphaIsOne],
            outputAlphaType: outputAlphaType
        )
        let kernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
            fragmentFunctionDescriptor: fragmentFunctionDescriptor,
            vertexDescriptor: nil,
            colorAttachmentCount: 1,
            alphaTypeHandlingRule: rule
        )
        kernels[configuration] = kernel
        return kernel
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return MTIRGBColorSpaceConversionFilter.convert(inputImage,
                                                        from: inputColorSpace,
                                                        to: outputColorSpace,
                                                        alphaType: outputAlphaType,
                                                        pixelFormat: outputPixelFormat)
    }

    public static func convert(
        _ image: MTIImage,
        from inputColorSpace: MTIRGBColorSpace,
        to outputColorSpace: MTIRGBColorSpace,
        alphaType: MTIAlphaType,
        pixelFormat: MTLPixelFormat = .unspecified
    ) -> MTIImage {
        kernel(inputColorSpace: inputColorSpace,
               outputColorSpace: outputColorSpace,
               inputAlphaType: image.alphaType,
               outputAlphaType: alphaType)
            .apply(
                to: [image],
                parameters: [:],
                outputDimensions: image.dimensions,
                outputPixelFormat: pixelFormat
            )
    }
}
