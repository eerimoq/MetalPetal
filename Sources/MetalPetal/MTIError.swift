//
//  MTIError.swift
//  MetalPetal
//
//  Created by YuAo on 10/08/2017.
//

import Foundation

public enum MTIError: Error {
    // Core errors
    case functionNotFound
    case failedToCreateSamplerState
    case failedToCreateTexture
    case failedToCreateCommandEncoder
    case failedToCreateHeap
    case blendFunctionNotFound
    // Texture loading errors
    case unsupportedCVPixelBufferFormat
    case textureDimensionsMismatch
    case textureLoaderFailedToCreateCGContext
    case textureLoaderFailedToCreateCGImage
    // Kernel errors
    case parameterDataSizeMismatch
    case mpsKernelInputCountMismatch
    case mpsKernelNotSupported
    case textureBindingFailed
    case parameterDataTypeMismatch
    // Render errors
    case emptyDrawable
    case emptyDrawableTexture
    case failedToCreateCGImageFromCVPixelBuffer
    case failedToCreateCVPixelBuffer
    // For operations that do not support cross device or cross context rendering.
    case crossDeviceRendering
    case crossContextRendering
    case invalidTextureDimension
    // For features not available on iOS simulator.
    case featureNotAvailableOnSimulator
}
