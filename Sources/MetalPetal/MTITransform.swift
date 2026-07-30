//
//  MTITransform.swift
//  MetalPetal
//
//  Created by Yu Ao on 28/10/2017.
//

import Foundation
import QuartzCore
import simd

public func MTIMakeOrthographicMatrix(
    _ left: Float,
    _ right: Float,
    _ top: Float,
    _ bottom: Float,
    _ near: Float,
    _ far: Float
) -> simd_float4x4 {
    let r_l = right - left
    let t_b = bottom - top
    let f_n = far - near
    let tx = -(right + left) / (right - left)
    let ty = -(top + bottom) / (bottom - top)
    let tz = -(far + near) / (far - near)

    let scale: Float = 2.0

    return simd_float4x4(columns: (
        simd_float4(scale / r_l, 0, 0, tx),
        simd_float4(0, scale / t_b, 0, ty),
        simd_float4(0, 0, scale / f_n, tz),
        simd_float4(0, 0, 0, 1)
    ))
}

public func MTIMakePerspectiveMatrix(
    _ left: Float,
    _ right: Float,
    _ top: Float,
    _ bottom: Float,
    _ near: Float,
    _ far: Float
) -> simd_float4x4 {
    let near = -near
    let far = -far

    return simd_float4x4(columns: (
        simd_float4(2 * near / (right - left), 0, (right + left) / (right - left), 0),
        simd_float4(0, 2 * near / (bottom - top), (top + bottom) / (bottom - top), 0),
        simd_float4(0, 0, -far / (far - near), -(far * near) / (far - near)),
        simd_float4(0, 0, -1, 0)
    ))
}

public func MTIMakeTransformMatrixFromCATransform3D(_ transform: CATransform3D) -> simd_float4x4 {
    simd_matrix_from_rows(
        simd_make_float4(
            Float(transform.m11),
            Float(transform.m12),
            Float(transform.m13),
            Float(transform.m14)
        ),
        simd_make_float4(
            Float(transform.m21),
            Float(transform.m22),
            Float(transform.m23),
            Float(transform.m24)
        ),
        simd_make_float4(
            Float(transform.m31),
            Float(transform.m32),
            Float(transform.m33),
            Float(transform.m34)
        ),
        simd_make_float4(
            Float(transform.m41),
            Float(transform.m42),
            Float(transform.m43),
            Float(transform.m44)
        )
    )
}
