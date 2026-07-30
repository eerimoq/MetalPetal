//
//  MTIPixelFormat.swift
//  MetalPetal
//
//  Created by Yu Ao on 11/10/2017.
//

import Metal

public extension MTLPixelFormat {
    static let unspecified = MTLPixelFormat.invalid
    static let yCbCr8_420_2p = MTLPixelFormat(rawValue: 500)!
    static let yCbCr8_420_2p_srgb = MTLPixelFormat(rawValue: 520)!
    static let yCbCr10_420_2p = MTLPixelFormat(rawValue: 505)!
    static let yCbCr10_420_2p_srgb = MTLPixelFormat(rawValue: 525)!
}

public func MTIDeviceSupportsYCBCRPixelFormat(_ device: MTLDevice) -> Bool {
    device.supportsFamily(.apple3)
}
