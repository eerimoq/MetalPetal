//
//  MTITransformFilter.swift
//  MetalPetal
//

import Foundation
import Metal
import QuartzCore
import simd

/*
           ^  y+
           |
           |
     +--+--+--+--+
     |/////|/////|
 ----|-----|-----|---> x+
     |/////|/////|
     +--+--+--+--+
           |
           |
 */

private func transformMatrix(imageSize: CGSize,
                             viewport: CGRect,
                             fieldOfView: Float,
                             transform: CATransform3D) -> simd_float4x4
{
    if fieldOfView > 0.0 {
        let near = -imageSize.width * 0.5 / CGFloat(tan(fieldOfView / 2.0))
        let far = near * 2.0
        let transformToCameraCoordinates = CATransform3DMakeTranslation(0, 0, near)
        let combinedTransform = CATransform3DConcat(transform, transformToCameraCoordinates)
        let transformMatrix = MTIMakeTransformMatrixFromCATransform3D(combinedTransform)
        let perspectiveMatrix = MTIMakePerspectiveMatrix(Float(viewport.minX), Float(viewport.maxX),
                                                         Float(viewport.minY), Float(viewport.maxY),
                                                         Float(near), Float(far))
        return simd_mul(transformMatrix, perspectiveMatrix)
    } else {
        let transformMatrix = MTIMakeTransformMatrixFromCATransform3D(transform)
        let orthographicMatrix = MTIMakeOrthographicMatrix(Float(viewport.minX), Float(viewport.maxX),
                                                           Float(viewport.minY), Float(viewport.maxY),
                                                           0, 1)
        return simd_mul(transformMatrix, orthographicMatrix)
    }
}

public func MTITransformFilterApplyTransformToImage(
    _ image: MTIImage,
    _ transform: CATransform3D,
    _ fieldOfView: Float,
    _ rasterSampleCount: Int,
    _ viewport: MTITransformFilter.Viewport,
    _ outputPixelFormat: MTLPixelFormat
) -> MTIImage {
    let inputImageSize = image.size
    let imageRect = CGRect(
        x: -0.5 * inputImageSize.width,
        y: -inputImageSize.height * 0.5,
        width: inputImageSize.width,
        height: inputImageSize.height
    )
    var viewport = viewport
    if viewport.size.width * viewport.size.height == 0 {
        viewport = MTITransformFilter.defaultViewport(for: image)
    }
    var tl = simd_make_float4(Float(imageRect.minX), Float(imageRect.minY), 0, 1)
    var tr = simd_make_float4(Float(imageRect.maxX), Float(imageRect.minY), 0, 1)
    var bl = simd_make_float4(Float(imageRect.minX), Float(imageRect.maxY), 0, 1)
    var br = simd_make_float4(Float(imageRect.maxX), Float(imageRect.maxY), 0, 1)
    let matrix = transformMatrix(
        imageSize: inputImageSize,
        viewport: viewport,
        fieldOfView: fieldOfView,
        transform: transform
    )
    tl = simd_mul(tl, matrix)
    tr = simd_mul(tr, matrix)
    bl = simd_mul(bl, matrix)
    br = simd_mul(br, matrix)
    let geometry = MTIVertices(vertices: [
        MTIVertex(position: (tl.x, tl.y, 0, tl.w), textureCoordinate: (0, 1)),
        MTIVertex(position: (tr.x, tr.y, 0, tr.w), textureCoordinate: (1, 1)),
        MTIVertex(position: (bl.x, bl.y, 0, bl.w), textureCoordinate: (0, 0)),
        MTIVertex(position: (br.x, br.y, 0, br.w), textureCoordinate: (1, 0)),
    ], primitiveType: .triangleStrip)
    let outputDescriptor = MTIRenderPassOutputDescriptor(
        dimensions: MTITextureDimensions(cgSize: viewport.size),
        pixelFormat: outputPixelFormat,
        loadAction: .clear
    )
    let command = MTIRenderCommand(
        kernel: MTIRenderPipelineKernel.passthrough,
        geometry: geometry,
        images: [image],
        parameters: [:]
    )
    return [command].makeImages(
        rasterSampleCount: rasterSampleCount,
        outputDescriptors: [outputDescriptor]
    )[0]
}

public final class MTITransformFilter: MTIUnaryFilter {
    public typealias Viewport = CGRect
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var transform: CATransform3D = CATransform3DIdentity
    /// Determines the receiver's field of view on the X And Y axis (in radian).
    ///
    /// When fov is zero the orthographic matrix will be applied. Otherwise, use the perspective
    /// matrix. Value in [0, M_PI) is valid. Defaults to 0.
    public var fieldOfView: Float = 0.0
    public var viewport: Viewport = CGRect(x: 0, y: 0, width: 0, height: 0)
    public var rasterSampleCount: Int = 1

    public init() {}

    public static func defaultViewport(for image: MTIImage) -> Viewport {
        let inputImageSize = image.size
        return CGRect(
            x: -0.5 * inputImageSize.width,
            y: -inputImageSize.height * 0.5,
            width: inputImageSize.width,
            height: inputImageSize.height
        )
    }

    public static func minimumEnclosingViewport(
        for image: MTIImage,
        transform: CATransform3D,
        fieldOfView: Float
    ) -> Viewport {
        let imageRect = defaultViewport(for: image)
        let tl = simd_make_float4(Float(imageRect.minX), Float(imageRect.minY), 0, 1)
        let tr = simd_make_float4(Float(imageRect.maxX), Float(imageRect.minY), 0, 1)
        let bl = simd_make_float4(Float(imageRect.minX), Float(imageRect.maxY), 0, 1)
        let br = simd_make_float4(Float(imageRect.maxX), Float(imageRect.maxY), 0, 1)
        var points = [tl, tr, bl, br]
        let matrix = transformMatrix(
            imageSize: image.size,
            viewport: imageRect,
            fieldOfView: fieldOfView,
            transform: transform
        )
        for i in 0 ..< 4 {
            points[i] = simd_mul(points[i], matrix)
            points[i] /= points[i].w
            points[i] *= simd_make_float4(
                Float(imageRect.size.width / 2),
                Float(imageRect.size.height / 2),
                0,
                0
            )
        }
        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxX = Float.leastNormalMagnitude
        var maxY = Float.leastNormalMagnitude
        for i in 0 ..< 4 {
            minX = min(minX, points[i].x)
            minY = min(minY, points[i].y)
            maxX = max(maxX, points[i].x)
            maxY = max(maxY, points[i].y)
        }
        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX),
            height: CGFloat(maxY - minY)
        )
    }

    public var defaultViewport: Viewport {
        guard let inputImage else {
            return CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        return MTITransformFilter.defaultViewport(for: inputImage)
    }

    public var minimumEnclosingViewport: Viewport {
        guard let inputImage else {
            return CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        return MTITransformFilter.minimumEnclosingViewport(
            for: inputImage,
            transform: transform,
            fieldOfView: fieldOfView
        )
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return MTITransformFilterApplyTransformToImage(
            inputImage,
            transform,
            fieldOfView,
            rasterSampleCount,
            viewport,
            outputPixelFormat
        )
    }
}
