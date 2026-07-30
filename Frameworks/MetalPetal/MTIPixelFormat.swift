//
//  MTIPixelFormat.swift
//  Pods
//
//  Created by Yu Ao on 2018/11/8.
//

import Metal

public extension MTLPixelFormat {
    static let unspecified = MTLPixelFormat.invalid
    static let yCbCr8_420_2p = __MTIPixelFormatYCBCR8_420_2P
    static let yCbCr8_420_2p_srgb = __MTIPixelFormatYCBCR8_420_2P_sRGB
    static let yCbCr10_420_2p = __MTIPixelFormatYCBCR10_420_2P
    static let yCbCr10_420_2p_srgb = __MTIPixelFormatYCBCR10_420_2P_sRGB
}
