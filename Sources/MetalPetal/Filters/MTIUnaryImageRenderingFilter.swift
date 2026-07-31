//
//  MTIUnaryImageRenderingFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 10/10/2017.
//

import CoreGraphics
import Foundation
import Metal
import os
import simd

public class MTIUnaryImageRenderingFilter: MTIUnaryFilter {
    public init() {}

    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var orientation: MTIImageOrientation = .up
    private static var kernels: [MTIFunctionDescriptor: MTIRenderPipelineKernel] = [:]
    private static let kernelsLock = OSAllocatedUnfairLock()

    public static func kernel() -> MTIRenderPipelineKernel {
        let fragmentFunctionDescriptor = fragmentFunctionDescriptor()
        kernelsLock.lock()
        defer {
            kernelsLock.unlock()
        }
        if let kernel = kernels[fragmentFunctionDescriptor] {
            return kernel
        }
        let kernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
            fragmentFunctionDescriptor: fragmentFunctionDescriptor,
            vertexDescriptor: nil,
            colorAttachmentCount: 1,
            alphaTypeHandlingRule: alphaTypeHandlingRule()
        )
        kernels[fragmentFunctionDescriptor] = kernel
        return kernel
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return type(of: self).image(
            byProcessingImage: inputImage,
            orientation: orientation,
            parameters: parameters,
            outputPixelFormat: outputPixelFormat,
            outputImageSize: outputImageSize(forInputImage: inputImage)
        )
    }

    public static func image(
        byProcessingImage image: MTIImage,
        withInputParameters parameters: [String: Any],
        outputPixelFormat: MTLPixelFormat
    ) -> MTIImage {
        self.image(
            byProcessingImage: image,
            orientation: .up,
            parameters: parameters,
            outputPixelFormat: outputPixelFormat
        )
    }

    public static func image(
        byProcessingImage image: MTIImage,
        orientation: MTIImageOrientation,
        parameters: [String: Any],
        outputPixelFormat: MTLPixelFormat
    ) -> MTIImage {
        self.image(
            byProcessingImage: image,
            orientation: orientation,
            parameters: parameters,
            outputPixelFormat: outputPixelFormat,
            outputImageSize: defaultOutputImageSize(forInputImage: image, orientation: orientation)
        )
    }

    public static func image(
        byProcessingImage image: MTIImage,
        orientation: MTIImageOrientation,
        parameters: [String: Any],
        outputPixelFormat: MTLPixelFormat,
        outputImageSize: CGSize
    ) -> MTIImage {
        let outputDescriptor = MTIRenderPassOutputDescriptor(
            dimensions: MTITextureDimensions(cgSize: outputImageSize),
            pixelFormat: outputPixelFormat
        )
        let geometry = vertices(
            forDrawingIn: CGRect(x: -1, y: -1, width: 2, height: 2),
            orientation: orientation
        )
        let command = MTIRenderCommand(
            kernel: kernel(),
            geometry: geometry,
            images: [image],
            parameters: parameters
        )
        return MTIRenderCommand.images(byPerforming: [command], outputDescriptors: [outputDescriptor])[0]
    }

    public static func shouldSwipeWidthAndHeight(whenRotatingToOrientation orientation: MTIImageOrientation)
        -> Bool
    {
        switch orientation {
        case .left, .rightMirrored, .right, .leftMirrored:
            true
        default:
            false
        }
    }

    public static func vertices(forDrawingIn rect: CGRect, orientation: MTIImageOrientation) -> MTIVertices {
        let textureCoordinates: [(Float, Float)] = switch orientation {
        case .unknown, .up:
            [(0, 1), (1, 1), (0, 0), (1, 0)]
        case .upMirrored:
            [(1, 1), (0, 1), (1, 0), (0, 0)]
        case .down:
            [(1, 0), (0, 0), (1, 1), (0, 1)]
        case .left:
            [(1, 1), (1, 0), (0, 1), (0, 0)]
        case .right:
            [(0, 0), (0, 1), (1, 0), (1, 1)]
        case .downMirrored:
            [(0, 0), (1, 0), (0, 1), (1, 1)]
        case .leftMirrored:
            [(0, 1), (0, 0), (1, 1), (1, 0)]
        case .rightMirrored:
            [(1, 0), (1, 1), (0, 0), (0, 1)]
        }
        let l = Float(rect.minX)
        let r = Float(rect.maxX)
        let t = Float(rect.minY)
        let b = Float(rect.maxY)
        return MTIVertices(vertices: [
            MTIVertex(position: (l, t, 0, 1), textureCoordinate: textureCoordinates[0]),
            MTIVertex(position: (r, t, 0, 1), textureCoordinate: textureCoordinates[1]),
            MTIVertex(position: (l, b, 0, 1), textureCoordinate: textureCoordinates[2]),
            MTIVertex(position: (r, b, 0, 1), textureCoordinate: textureCoordinates[3]),
        ], primitiveType: .triangleStrip)
    }

    public static func defaultOutputImageSize(
        forInputImage inputImage: MTIImage,
        orientation: MTIImageOrientation
    ) -> CGSize {
        var size = inputImage.size
        if shouldSwipeWidthAndHeight(whenRotatingToOrientation: orientation) {
            size.width = inputImage.size.height
            size.height = inputImage.size.width
        }
        return size
    }

    public var parameters: [String: Any] {
        [:]
    }

    public func outputImageSize(forInputImage inputImage: MTIImage) -> CGSize {
        MTIUnaryImageRenderingFilter.defaultOutputImageSize(
            forInputImage: inputImage,
            orientation: orientation
        )
    }

    public class func fragmentFunctionDescriptor() -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: MTIFilterPassthroughFragmentFunctionName, libraryURL: nil)
    }

    public class func alphaTypeHandlingRule() -> MTIAlphaTypeHandlingRule {
        if self == MTIUnaryImageRenderingFilter.self {
            // for MTIUnaryImageRenderingFilter
            MTIAlphaTypeHandlingRule.passthrough
        } else {
            // Subclass default
            MTIAlphaTypeHandlingRule.general
        }
    }
}
