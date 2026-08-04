//
//  MTIError.swift
//  MetalPetal
//
//  Created by YuAo on 10/08/2017.
//

import Foundation

public enum MTIError: Error, Equatable {
    // Core errors
    case functionNotFound
    case failedToCreateSamplerState
    case failedToCreateTexture
    case failedToCreateCommandEncoder
    case failedToCreateHeap
    case blendFunctionNotFound
    case imageBufferIsNotBackedByIOSurface
    case coreVideoDoesNotSupportIOSurface
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
    case imageViewContextNotFound
    case imageViewSameImage
    case libraryNotFound
    case cvMetalTextureCacheFailedToInitialize(CVReturn)
    case cvMetalTextureCacheFailedToCreate(CVReturn)
    case cvPixelBufferPoolError(CVReturn)
    // Video composition errors
    case cannotGenerateOutputPixelBuffer
    case unsupportedVideoCompositionInstruction
    // Core Image interoperability errors
    case failedToCreateCIImage
    case coreImageFilterReturnedNilOutput
}
