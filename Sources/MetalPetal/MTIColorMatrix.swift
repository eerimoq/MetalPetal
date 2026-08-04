//
//  MTIColorMatrix.swift
//  MetalPetal
//
//  Created by Yu Ao on 25/10/2017.
//

import Accelerate
import Foundation
import simd

public struct MTIColorMatrix: Equatable {
    public var matrix: simd_float4x4
    public var bias: simd_float4

    public init(matrix: simd_float4x4, bias: simd_float4) {
        self.matrix = matrix
        self.bias = bias
    }

    static let identity = MTIColorMatrix(
        matrix: simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )),
        bias: SIMD4<Float>(0, 0, 0, 0)
    )

    static let rgbColorInvert = MTIColorMatrix(
        matrix: simd_float4x4(columns: (
            SIMD4<Float>(-1, 0, 0, 0),
            SIMD4<Float>(0, -1, 0, 0),
            SIMD4<Float>(0, 0, -1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )),
        bias: SIMD4<Float>(1, 1, 1, 0)
    )

    var isIdentity: Bool {
        self == .identity
    }

    func concat(with other: MTIColorMatrix) -> MTIColorMatrix {
        var a = MTIColorMatrix.fillFloat5x5(self)
        var b = MTIColorMatrix.fillFloat5x5(other)
        var result = [Float](repeating: 0, count: 25)
        vDSP_mmul(&a, 1, &b, 1, &result, 1, 5, 5, 5)
        return MTIColorMatrix.makeFromFloat5x5(result)
    }

    init(exposure: Float) {
        let power = powf(2, exposure)
        var matrix = matrix_identity_float4x4
        matrix[0][0] = power
        matrix[1][1] = power
        matrix[2][2] = power
        self.init(matrix: matrix, bias: SIMD4<Float>(0, 0, 0, 0))
    }

    init(saturation: Float, grayColorTransform: simd_float3) {
        let lumR = grayColorTransform.x
        let lumG = grayColorTransform.y
        let lumB = grayColorTransform.z
        let s = saturation
        let sr = (1 - s) * lumR
        let sg = (1 - s) * lumG
        let sb = (1 - s) * lumB
        self = MTIColorMatrix.identity
        matrix[0][0] = sr + s
        matrix[1][0] = sr
        matrix[2][0] = sr
        matrix[0][1] = sg
        matrix[1][1] = sg + s
        matrix[2][1] = sg
        matrix[0][2] = sb
        matrix[1][2] = sb
        matrix[2][2] = sb + s
    }

    init(brightness: Float) {
        self = MTIColorMatrix.identity
        bias[0] = brightness
        bias[1] = brightness
        bias[2] = brightness
    }

    init(contrast: Float) {
        let c = contrast
        let t = (1 - c) / 2.0
        self = MTIColorMatrix.identity
        bias[0] = t
        bias[1] = t
        bias[2] = t
        var matrix = matrix_identity_float4x4
        matrix[0][0] = c
        matrix[1][1] = c
        matrix[2][2] = c
        self.matrix = matrix
    }

    init(opacity: Float) {
        self = MTIColorMatrix.identity
        matrix[3][3] = opacity
    }

    // Fills a row-major 5x5 float matrix (as used by `vDSP_mmul`) from the color matrix.
    private static func fillFloat5x5(_ m: MTIColorMatrix) -> [Float] {
        var s = [Float](repeating: 0, count: 25)
        let c = m.matrix
        s[0 * 5 + 0] = c[0][0]
        s[1 * 5 + 0] = c[0][1]
        s[2 * 5 + 0] = c[0][2]
        s[3 * 5 + 0] = c[0][3]
        s[0 * 5 + 1] = c[1][0]
        s[1 * 5 + 1] = c[1][1]
        s[2 * 5 + 1] = c[1][2]
        s[3 * 5 + 1] = c[1][3]
        s[0 * 5 + 2] = c[2][0]
        s[1 * 5 + 2] = c[2][1]
        s[2 * 5 + 2] = c[2][2]
        s[3 * 5 + 2] = c[2][3]
        s[0 * 5 + 3] = c[3][0]
        s[1 * 5 + 3] = c[3][1]
        s[2 * 5 + 3] = c[3][2]
        s[3 * 5 + 3] = c[3][3]
        s[4 * 5 + 0] = m.bias[0]
        s[4 * 5 + 1] = m.bias[1]
        s[4 * 5 + 2] = m.bias[2]
        s[4 * 5 + 3] = m.bias[3]
        s[4 * 5 + 4] = 1
        return s
    }

    private static func makeFromFloat5x5(_ s: [Float]) -> MTIColorMatrix {
        var m = MTIColorMatrix.identity
        m.matrix[0][0] = s[0 * 5 + 0]
        m.matrix[0][1] = s[1 * 5 + 0]
        m.matrix[0][2] = s[2 * 5 + 0]
        m.matrix[0][3] = s[3 * 5 + 0]
        m.matrix[1][0] = s[0 * 5 + 1]
        m.matrix[1][1] = s[1 * 5 + 1]
        m.matrix[1][2] = s[2 * 5 + 1]
        m.matrix[1][3] = s[3 * 5 + 1]
        m.matrix[2][0] = s[0 * 5 + 2]
        m.matrix[2][1] = s[1 * 5 + 2]
        m.matrix[2][2] = s[2 * 5 + 2]
        m.matrix[2][3] = s[3 * 5 + 2]
        m.matrix[3][0] = s[0 * 5 + 3]
        m.matrix[3][1] = s[1 * 5 + 3]
        m.matrix[3][2] = s[2 * 5 + 3]
        m.matrix[3][3] = s[3 * 5 + 3]
        m.bias[0] = s[4 * 5 + 0]
        m.bias[1] = s[4 * 5 + 1]
        m.bias[2] = s[4 * 5 + 2]
        m.bias[3] = s[4 * 5 + 3]
        return m
    }
}
