//
//  MTIError.swift
//  MetalPetal
//
//  Created by YuAo on 10/08/2017.
//

import Foundation

public let MTIErrorDomain = "MTIErrorDomain"

public struct MTIError: CustomNSError, Hashable, _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError error: NSError) {
        precondition(error.domain == MTIErrorDomain)
        _nsError = error
    }

    public static var errorDomain: String { MTIErrorDomain }

    public enum Code: Int, _ErrorCodeProtocol {
        public typealias _ErrorType = MTIError

        // Core errors
        case deviceNotFound = 1001
        case functionNotFound = 1002
        case failedToCreateSamplerState = 1003
        case failedToCreateTexture = 1004
        case failedToCreateCommandEncoder = 1005
        case failedToCreateHeap = 1006
        case defaultLibraryNotFound = 1007
        case blendFunctionNotFound = 1008

        // Texture loading errors
        case unsupportedCVPixelBufferFormat = 2001
        case textureDimensionsMismatch = 2002
        case textureLoaderFailedToCreateCGContext = 2004
        case textureLoaderFailedToCreateCGImage = 2005

        // Image errors
        case unsupportedImageCachePolicy = 3001

        // Kernel errors
        case parameterDataSizeMismatch = 4001
        case unsupportedParameterType = 4002
        case mpsKernelInputCountMismatch = 4003
        case mpsKernelNotSupported = 4004
        case textureBindingFailed = 4005
        case parameterDataTypeMismatch = 4006

        // Render errors
        case emptyDrawable = 5001
        case emptyDrawableTexture = 5101
        case failedToCreateCGImageFromCVPixelBuffer = 5002
        case failedToCreateCVPixelBuffer = 5003
        case invalidCVPixelBufferRenderingAPI = 5004
        case failedToGetRenderedBuffer = 5005

        // For operations that do not support cross device or cross context rendering.
        case crossDeviceRendering = 5006
        case crossContextRendering = 5007

        case invalidTextureDimension = 5008

        // For features not available on iOS simulator.
        case featureNotAvailableOnSimulator = 6001
    }
}

/// Create an NSError with `MTIErrorDomain` and the specified error code and user info. Creating a symbolic
/// breakpoint for `_MTIErrorCreate` can help you locate the source of the error.
public func _MTIErrorCreate(
    _ code: MTIError.Code,
    _ defaultDescription: String,
    _ userInfo: [AnyHashable: Any]?
) -> NSError {
    var info: [String: Any] = [:]
    if let userInfo {
        for (key, value) in userInfo {
            if let key = key.base as? String {
                info[key] = value
            }
        }
    }
    if info[NSLocalizedDescriptionKey] == nil {
        info[NSLocalizedDescriptionKey] = defaultDescription
    }
    return NSError(domain: MTIErrorDomain, code: code.rawValue, userInfo: info)
}
