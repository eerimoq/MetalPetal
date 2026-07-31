//
//  MTIColorLookupFilter.swift
//  MetalPetal
//
//  Created by 杨乃川 on 2017/10/12.
//

import CoreGraphics
import Foundation
import Metal

public enum MTIColorLookupTableType: Int {
    case typeUnknown
    /// The look up table contents must a 2D image representing `n` slices of a unit color cube texture,
    /// arranged in an square of `n` images. For instance, a color cube of dimension 64x64x64 should be
    /// provided as an image of size 512x512 - sqrt(64x64x64).
    case type2DSquare
    /// The look up table contents must a 2D image representing `n` slices of a unit color cube texture,
    /// arranged in an horizontal row of `n` images. For instance, a color cube of dimension 16x16x16 should
    /// be provided as an image of size 256x16.
    case type2DHorizontalStrip
    case type2DVerticalStrip
    case type3D
}

public struct MTIColorLookupTableInfo {
    public let type: MTIColorLookupTableType
    public let dimension: Int

    public init(type: MTIColorLookupTableType, dimension: Int) {
        self.type = type
        self.dimension = dimension
    }

    init(colorLookupTableImageDimensions dimensions: MTITextureDimensions) {
        if dimensions.depth == 1 {
            var type = MTIColorLookupTableType.typeUnknown
            var dimension = 0
            let width = dimensions.width
            let height = dimensions.height
            if width == height {
                // may be a 2d square
                let possibleDimension = Int(round(pow(Double(width * height), 1.0 / 3.0)))
                if possibleDimension * possibleDimension * possibleDimension == width * height {
                    dimension = possibleDimension
                    type = .type2DSquare
                }
            } else {
                // may be a 2d strip
                if height * height == width {
                    type = .type2DHorizontalStrip
                    dimension = height
                } else if width * width == height {
                    type = .type2DVerticalStrip
                    dimension = width
                }
            }
            self.init(type: type, dimension: dimension)
        } else {
            if dimensions.width == dimensions.height, dimensions.width == dimensions.depth {
                self.init(type: .type3D, dimension: dimensions.width)
            } else {
                self.init(type: .typeUnknown, dimension: 0)
            }
        }
    }
}

public final class MTIColorLookupFilter: MTIFilter {
    public init() {}

    public var inputImage: MTIImage?
    public var inputColorLookupTable: MTIImage? {
        didSet {
            if let inputColorLookupTable {
                inputColorLookupTableInfo =
                    MTIColorLookupTableInfo(colorLookupTableImageDimensions: inputColorLookupTable.dimensions)
            } else {
                inputColorLookupTableInfo = nil
            }
        }
    }

    public private(set) var inputColorLookupTableInfo: MTIColorLookupTableInfo?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    /// Specifies the intensity (in the range [0, 1]) of the operation.
    public var intensity: Float = 1.0

    private static let squareLookupKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "colorLookup2DSquare")
    )

    private static let horizontalStripLookupKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "colorLookup2DHorizontalStrip")
    )

    private static let verticalStripLookupKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "colorLookup2DVerticalStrip")
    )

    private static let lookup3DKernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "colorLookup3D")
    )

    public var outputImage: MTIImage? {
        guard let inputImage,
              let inputColorLookupTable,
              let info = inputColorLookupTableInfo
        else {
            return nil
        }
        if info.type == .typeUnknown || info.dimension == 0 {
            return nil
        }
        let kernel: MTIRenderPipelineKernel
        switch info.type {
        case .type2DSquare:
            kernel = MTIColorLookupFilter.squareLookupKernel
        case .type2DHorizontalStrip:
            kernel = MTIColorLookupFilter.horizontalStripLookupKernel
        case .type2DVerticalStrip:
            kernel = MTIColorLookupFilter.verticalStripLookupKernel
        case .type3D:
            kernel = MTIColorLookupFilter.lookup3DKernel
        case .typeUnknown:
            return nil
        }
        return kernel.apply(to: [inputImage, inputColorLookupTable],
                            parameters: ["intensity": intensity,
                                         "dimension": Int32(info.dimension)],
                            outputDimensions: MTITextureDimensions(cgSize: inputImage.size),
                            outputPixelFormat: outputPixelFormat)
    }

    private static let kernel2DSquareTo3D = MTIComputePipelineKernel(
        computeFunctionDescriptor: MTIFunctionDescriptor(name: "colorLookupTable2DSquareTo3D"),
        alphaTypeHandlingRule: .passthrough
    )

    private static let kernel2DStripVerticalTo3D = MTIComputePipelineKernel(
        computeFunctionDescriptor: MTIFunctionDescriptor(name: "colorLookupTable2DStripVerticalTo3D"),
        alphaTypeHandlingRule: .passthrough
    )

    private static let kernel2DStripHorizontalTo3D = MTIComputePipelineKernel(
        computeFunctionDescriptor: MTIFunctionDescriptor(name: "colorLookupTable2DStripHorizontalTo3D"),
        alphaTypeHandlingRule: .passthrough
    )

    public static func make3DColorLookupTable(from image: MTIImage,
                                              pixelFormat: MTLPixelFormat) -> MTIImage?
    {
        let info = MTIColorLookupTableInfo(colorLookupTableImageDimensions: image.dimensions)
        if info.type == .typeUnknown || info.dimension == 0 {
            return nil
        }
        let kernel: MTIComputePipelineKernel
        switch info.type {
        case .type3D:
            return image
        case .type2DSquare:
            kernel = kernel2DSquareTo3D
        case .type2DVerticalStrip:
            kernel = kernel2DStripVerticalTo3D
        case .type2DHorizontalStrip:
            kernel = kernel2DStripHorizontalTo3D
        case .typeUnknown:
            return nil
        }
        return kernel.apply(toInputImages: [image],
                            parameters: ["dimension": Int32(info.dimension)],
                            outputTextureDimensions: MTITextureDimensions(
                                width: info.dimension,
                                height: info.dimension,
                                depth: info.dimension
                            ),
                            outputPixelFormat: pixelFormat)
    }
}
