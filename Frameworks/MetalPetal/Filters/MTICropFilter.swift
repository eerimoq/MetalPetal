//
//  MTICropFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 28/10/2017.
//

import CoreGraphics
import Foundation
import Metal

// Rounding policies:
//
// Original Value  1.2 | 1.21 | 1.25 | 1.35 | 1.27
// -----------------------------------------------
// Plain           1.2 | 1.2  | 1.3  | 1.4  | 1.3
// Floor           1.2 | 1.2  | 1.2  | 1.3  | 1.2
// Ceiling         1.2 | 1.3  | 1.3  | 1.4  | 1.3

public enum MTICropFilterRoundingMode: UInt {
    case plain
    case ceiling
    case floor
}

public final class MTICropFilter: NSObject, MTIUnaryFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var cropRegion: MTICropRegion = .init(
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        unit: .percentage
    )
    public var scale: Float = 1
    public var roundingMode: MTICropFilterRoundingMode = .plain

    private static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughFragmentFunctionName),
        vertexDescriptor: nil,
        colorAttachmentCount: 1,
        alphaTypeHandlingRule: .passthrough
    )

    public var outputImage: MTIImage? {
        guard let inputImage, cropRegion.bounds.size.width > 0, cropRegion.bounds.size.height > 0 else {
            return nil
        }
        let cropRect: CGRect = switch cropRegion.unit {
        case .pixel:
            cropRegion.bounds
        case .percentage:
            CGRect(x: cropRegion.bounds.origin.x * inputImage.size.width,
                   y: cropRegion.bounds.origin.y * inputImage.size.height,
                   width: cropRegion.bounds.size.width * inputImage.size.width,
                   height: cropRegion.bounds.size.height * inputImage.size.height)
        }
        let rect = CGRect(x: -1, y: -1, width: 2, height: 2)
        let l = Float(rect.minX)
        let r = Float(rect.maxX)
        let t = Float(rect.minY)
        let b = Float(rect.maxY)
        let minX = Float(cropRect.origin.x / inputImage.size.width)
        let minY = Float(cropRect.origin.y / inputImage.size.height)
        let maxX = Float(cropRect.maxX / inputImage.size.width)
        let maxY = Float(cropRect.maxY / inputImage.size.height)
        let geometry = MTIVertices(vertices: [
            MTIVertex(position: (l, t, 0, 1), textureCoordinate: (minX, maxY)),
            MTIVertex(position: (r, t, 0, 1), textureCoordinate: (maxX, maxY)),
            MTIVertex(position: (l, b, 0, 1), textureCoordinate: (minX, minY)),
            MTIVertex(position: (r, b, 0, 1), textureCoordinate: (maxX, minY)),
        ], primitiveType: .triangleStrip)
        let roundingFunction: (Double) -> Double = switch roundingMode {
        case .plain:
            round
        case .floor:
            floor
        case .ceiling:
            ceil
        }
        let outputWidth = Int(roundingFunction(Double(cropRect.size.width) * Double(scale)))
        let outputHeight = Int(roundingFunction(Double(cropRect.size.height) * Double(scale)))
        if CGFloat(outputWidth) == inputImage.size.width, CGFloat(outputHeight) == inputImage.size.height,
           cropRect.origin.x == 0, cropRect.origin.y == 0
        {
            return inputImage
        }
        let outputDescriptor = MTIRenderPassOutputDescriptor(
            dimensions: MTITextureDimensions(width: outputWidth, height: outputHeight, depth: 1),
            pixelFormat: outputPixelFormat
        )
        let command = MTIRenderCommand(
            kernel: MTICropFilter.kernel,
            geometry: geometry,
            images: [inputImage],
            parameters: [:]
        )
        return [command].makeImages(outputDescriptors: [outputDescriptor]).first
    }
}
