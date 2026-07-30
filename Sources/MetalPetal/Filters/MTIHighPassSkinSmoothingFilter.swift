//
//  MTIHighPassSkinSmoothingFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 15/01/2018.
//

import Foundation
import Metal
import MetalPerformanceShaders

public final class MTIHighPassSkinSmoothingFilter: NSObject, MTIFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var amount: Float = 0.65
    public var radius: Float = 8.0 {
        didSet {
            blurFilter.radius = radius
        }
    }

    /// Setting this to `nil`, or to fewer than two points, restores the default control points.
    public var toneCurveControlPoints: [MTIVector]! {
        get {
            storedToneCurveControlPoints
        }
        set {
            if let newValue, newValue.count >= 2 {
                storedToneCurveControlPoints = newValue
            } else {
                storedToneCurveControlPoints = MTIHighPassSkinSmoothingFilter.defaultToneCurveControlPoints
            }
            toneCurveFilter.rgbCompositeControlPoints = storedToneCurveControlPoints
        }
    }

    private var storedToneCurveControlPoints = MTIHighPassSkinSmoothingFilter.defaultToneCurveControlPoints
    private let blurFilter = MTIMPSGaussianBlurFilter()
    private let toneCurveFilter = MTIRGBToneCurveFilter()

    override public init() {
        super.init()
        blurFilter.radius = radius
        toneCurveFilter.rgbCompositeControlPoints = storedToneCurveControlPoints
    }

    private static var defaultToneCurveControlPoints: [MTIVector] {
        [MTIVector(x: 0, y: 0),
         MTIVector(x: 120 / 255.0, y: 146 / 255.0),
         MTIVector(x: 1.0, y: 1.0)]
    }

    private static let gbChannelOverlayBlendKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "highPassSkinSmoothingGBChannelOverlay")
    )

    private static let maskProcessAndCompositeKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(
            name: "highPassSkinSmoothingMaskProcessAndComposite"
        )
    )

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        let bgChannelOverlayImage = MTIHighPassSkinSmoothingFilter.gbChannelOverlayBlendKernel.apply(
            to: [inputImage],
            parameters: [:],
            outputDimensions: MTITextureDimensions(cgSize: inputImage.size),
            outputPixelFormat: outputPixelFormat
        )
        blurFilter.inputImage = bgChannelOverlayImage
        let blurredBGChannelOverlayImage = blurFilter.outputImage
        blurFilter.inputImage = nil
        guard let blurredBGChannelOverlayImage else {
            return nil
        }
        return MTIHighPassSkinSmoothingFilter.maskProcessAndCompositeKernel.apply(
            to: [
                inputImage,
                bgChannelOverlayImage,
                blurredBGChannelOverlayImage,
                toneCurveFilter.toneCurveColorLookupImage,
            ],
            parameters: ["amount": amount],
            outputDimensions: MTITextureDimensions(cgSize: inputImage.size),
            outputPixelFormat: outputPixelFormat
        )
    }

    public static func isSupported(on device: MTLDevice) -> Bool {
        MPSSupportsMTLDevice(device)
    }
}
