//
//  MTIRGBToneCurveFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 12/01/2018.
//

import CoreGraphics
import Foundation
import Metal

public final class MTIRGBToneCurveFilter: NSObject, MTIFilter {
    public var inputImage: MTIImage?
    public var outputPixelFormat: MTLPixelFormat = .unspecified
    public var redControlPoints: [MTIVector] = [] {
        didSet {
            MTIRGBToneCurveFilter.updatePreparedSplineCurve(&redCurve, controlPoints: redControlPoints)
            toneCurveColorLookupImageIsDirty = true
        }
    }

    public var greenControlPoints: [MTIVector] = [] {
        didSet {
            MTIRGBToneCurveFilter.updatePreparedSplineCurve(&greenCurve, controlPoints: greenControlPoints)
            toneCurveColorLookupImageIsDirty = true
        }
    }

    public var blueControlPoints: [MTIVector] = [] {
        didSet {
            MTIRGBToneCurveFilter.updatePreparedSplineCurve(&blueCurve, controlPoints: blueControlPoints)
            toneCurveColorLookupImageIsDirty = true
        }
    }

    public var rgbCompositeControlPoints: [MTIVector] = [] {
        didSet {
            MTIRGBToneCurveFilter.updatePreparedSplineCurve(
                &rgbCurve,
                controlPoints: rgbCompositeControlPoints
            )
            toneCurveColorLookupImageIsDirty = true
        }
    }

    public var intensity: Float = 1.0
    private var redCurve = [Float](repeating: 0, count: 256)
    private var greenCurve = [Float](repeating: 0, count: 256)
    private var blueCurve = [Float](repeating: 0, count: 256)
    private var rgbCurve = [Float](repeating: 0, count: 256)
    /// The curves above are all zero, which produces an identity lookup table. Start dirty so the
    /// lookup image is built on first access even when no control points are ever set.
    private var toneCurveColorLookupImageIsDirty = true
    private var cachedToneCurveColorLookupImage: MTIImage?

    private static func updatePreparedSplineCurve(_ curve: inout [Float], controlPoints: [MTIVector]) {
        guard controlPoints.count > 1 else {
            for index in curve.indices {
                curve[index] = 0
            }
            return
        }
        // Sort the array.
        let sortedPoints = controlPoints.sorted(by: { $0.cgPointValue.x < $1.cgPointValue.x })
        let n = sortedPoints.count
        // Convert from (0, 1) to (0, 255).
        let convertedPoints = sortedPoints.map { CGPoint(
            x: $0.cgPointValue.x * 255,
            y: $0.cgPointValue.y * 255
        ) }
        // -------------
        // secondDerivative
        var matrix = [[Double]](repeating: [0, 0, 0], count: n)
        var result = [Double](repeating: 0, count: n)
        matrix[0][1] = 1
        // What about matrix[0][1] and matrix[0][0]? Assuming 0 for now (Brad L.)
        matrix[0][0] = 0
        matrix[0][2] = 0
        for i in stride(from: 1, to: n - 1, by: 1) {
            let p1 = convertedPoints[i - 1]
            let p2 = convertedPoints[i]
            let p3 = convertedPoints[i + 1]
            matrix[i][0] = Double(p2.x - p1.x) / 6
            matrix[i][1] = Double(p3.x - p1.x) / 3
            matrix[i][2] = Double(p3.x - p2.x) / 6
            result[i] = Double(p3.y - p2.y) / Double(p3.x - p2.x) - Double(p2.y - p1.y) / Double(p2.x - p1.x)
        }
        // What about result[0] and result[n-1]? Assuming 0 for now (Brad L.)
        result[0] = 0
        result[n - 1] = 0
        matrix[n - 1][1] = 1
        // What about matrix[n-1][0] and matrix[n-1][2]? For now, assuming they are 0 (Brad L.)
        matrix[n - 1][0] = 0
        matrix[n - 1][2] = 0
        // solving pass1 (up->down)
        for i in stride(from: 1, to: n, by: 1) {
            let k = matrix[i][0] / matrix[i - 1][1]
            matrix[i][1] -= k * matrix[i - 1][2]
            matrix[i][0] = 0
            result[i] -= k * result[i - 1]
        }
        // solving pass2 (down->up)
        for i in stride(from: n - 2, through: 0, by: -1) {
            let k = matrix[i][2] / matrix[i + 1][1]
            matrix[i][1] -= k * matrix[i + 1][0]
            matrix[i][2] = 0
            result[i] -= k * result[i + 1]
        }
        var sd = [Double](repeating: 0, count: n)
        for i in 0 ..< n {
            sd[i] = result[i] / matrix[i][1]
        }
        // -------------
        // The original computed sqrt((x - x)^2 + (x - y)^2), negated when x > y, which is `y - x`.
        func setCurvePoint(_ point: CGPoint) {
            curve[Int(point.x)] = Float(point.y - point.x)
        }
        for i in 0 ..< (n - 1) {
            let cur = convertedPoints[i]
            let next = convertedPoints[i + 1]
            var x = Int(cur.x)
            while x < Int(next.x) {
                let t = (Double(x) - Double(cur.x)) / (Double(next.x) - Double(cur.x))
                let a = 1 - t
                let b = t
                let h = Double(next.x) - Double(cur.x)
                var y = a * Double(cur.y) + b * Double(next.y) + (h * h / 6) *
                    ((a * a * a - a) * sd[i] + (b * b * b - b) * sd[i + 1])
                if y > 255.0 {
                    y = 255.0
                } else if y < 0.0 {
                    y = 0.0
                }
                setCurvePoint(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                x += 1
            }
        }
        // The above always misses the last point because the last point is the last next, so we approach but
        // don't equal it.
        setCurvePoint(convertedPoints[n - 1])
        // If we have a first point like (0.3, 0) we'll be missing some points at the beginning
        // that should be 0.
        if convertedPoints[0].x > 0 {
            var i = Int(convertedPoints[0].x)
            while i >= 0 {
                setCurvePoint(CGPoint(x: CGFloat(i), y: 0))
                i -= 1
            }
        }
        if convertedPoints[n - 1].x < 255 {
            var i = Int(convertedPoints[n - 1].x) + 1
            while i <= 255 {
                setCurvePoint(CGPoint(x: CGFloat(i), y: 255))
                i += 1
            }
        }
    }

    private static let kernel = MTIRenderPipelineKernel(
        vertexFunctionDescriptor: MTIFunctionDescriptor(name: MTIFilterPassthroughVertexFunctionName),
        fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "rgbToneCurveAdjust")
    )

    public var toneCurveColorLookupImage: MTIImage {
        if toneCurveColorLookupImageIsDirty || cachedToneCurveColorLookupImage == nil {
            var toneCurveByteArray = [UInt8](repeating: 0, count: 256 * 4)
            for currentCurveIndex in 0 ..< 256 {
                // BGRA for upload to texture
                let b = UInt8(min(max(Float(currentCurveIndex) + blueCurve[currentCurveIndex], 0), 255))
                toneCurveByteArray[currentCurveIndex * 4] = UInt8(min(
                    max(Float(b) + rgbCurve[Int(b)], 0),
                    255
                ))

                let g = UInt8(min(max(Float(currentCurveIndex) + greenCurve[currentCurveIndex], 0), 255))
                toneCurveByteArray[currentCurveIndex * 4 + 1] = UInt8(min(
                    max(Float(g) + rgbCurve[Int(g)], 0),
                    255
                ))

                let r = UInt8(min(max(Float(currentCurveIndex) + redCurve[currentCurveIndex], 0), 255))
                toneCurveByteArray[currentCurveIndex * 4 + 2] = UInt8(min(
                    max(Float(r) + rgbCurve[Int(r)], 0),
                    255
                ))

                toneCurveByteArray[currentCurveIndex * 4 + 3] = 255
            }
            cachedToneCurveColorLookupImage = MTIImage(
                bitmapData: Data(toneCurveByteArray),
                width: 256,
                height: 1,
                bytesPerRow: 256 * 4,
                pixelFormat: .bgra8Unorm,
                alphaType: .alphaIsOne
            )
            toneCurveColorLookupImageIsDirty = false
        }
        return cachedToneCurveColorLookupImage!
    }

    public var outputImage: MTIImage? {
        guard let inputImage else {
            return nil
        }
        return MTIRGBToneCurveFilter.kernel.apply(to: [inputImage, toneCurveColorLookupImage],
                                                  parameters: ["intensity": intensity],
                                                  outputDimensions: MTITextureDimensions(cgSize: inputImage
                                                      .size),
                                                  outputPixelFormat: outputPixelFormat)
    }
}
