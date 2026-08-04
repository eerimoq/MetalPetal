//
//  MTICVPixelBufferPool.swift
//  MetalPetal
//

import AVFoundation
import CoreVideo
import Foundation

/// Create a symbolic breakpoint of MTICVPixelBufferPoolIsOutOfBuffer to debug.
@inline(never)
private func MTICVPixelBufferPoolIsOutOfBuffer(_ pool: MTICVPixelBufferPool) {
    NSLog(
        "%@: Pool is out of buffers. Create a symbolic breakpoint of MTICVPixelBufferPoolIsOutOfBuffer to debug.",
        String(describing: pool)
    )
}

private func MTICVPixelBufferPoolFourCharCodeToString(_ code: FourCharCode) -> String {
    let bytes: [CChar] = [
        CChar(bitPattern: UInt8((code >> 24) & 0xFF)),
        CChar(bitPattern: UInt8((code >> 16) & 0xFF)),
        CChar(bitPattern: UInt8((code >> 8) & 0xFF)),
        CChar(bitPattern: UInt8(code & 0xFF)),
        0,
    ]
    let string = String(cString: bytes)
    return string.trimmingCharacters(in: .whitespaces)
}

public final class MTICVPixelBufferPool {
    private let pool: CVPixelBufferPool
    public var internalPool: CVPixelBufferPool {
        pool
    }

    public let poolAttributes: [AnyHashable: Any]
    public let pixelBufferAttributes: [AnyHashable: Any]
    public let pixelBufferWidth: Int
    public let pixelBufferHeight: Int
    public let minimumBufferCount: Int
    public let pixelFormatType: OSType
    public let pixelFormatDescription: String

    public init(cvPixelBufferPool pixelBufferPool: CVPixelBufferPool) {
        pool = pixelBufferPool
        let poolAttributes = (CVPixelBufferPoolGetAttributes(pixelBufferPool) as? [AnyHashable: Any]) ?? [:]
        let pixelBufferAttributes =
            (CVPixelBufferPoolGetPixelBufferAttributes(pixelBufferPool) as? [AnyHashable: Any]) ?? [:]
        self.poolAttributes = poolAttributes
        self.pixelBufferAttributes = pixelBufferAttributes
        pixelBufferWidth = (pixelBufferAttributes[kCVPixelBufferWidthKey as String] as? NSNumber)?
            .intValue ?? 0
        pixelBufferHeight = (pixelBufferAttributes[kCVPixelBufferHeightKey as String] as? NSNumber)?
            .intValue ?? 0
        minimumBufferCount = (poolAttributes[kCVPixelBufferPoolMinimumBufferCountKey as String] as? NSNumber)?
            .intValue ?? 0
        let pixelFormatType =
            (pixelBufferAttributes[kCVPixelBufferPixelFormatTypeKey as String] as? NSNumber)?.uint32Value ?? 0
        self.pixelFormatType = pixelFormatType
        pixelFormatDescription = MTICVPixelBufferPoolFourCharCodeToString(pixelFormatType)
    }

    public convenience init(
        poolAttributes: [AnyHashable: Any],
        pixelBufferAttributes: [AnyHashable: Any]
    ) throws {
        var pool: CVPixelBufferPool?
        let result = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )
        guard result == kCVReturnSuccess, let pool else {
            throw MTIError.cvPixelBufferPoolError(result)
        }
        self.init(cvPixelBufferPool: pool)
    }

    public convenience init(
        pixelBufferWidth width: Int,
        pixelBufferHeight height: Int,
        pixelFormatType: OSType,
        minimumBufferCount: Int
    ) throws {
        try self.init(poolAttributes: [kCVPixelBufferPoolMinimumBufferCountKey: minimumBufferCount],
                      pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
                                              kCVPixelBufferWidthKey: width,
                                              kCVPixelBufferHeightKey: height,
                                              kCVPixelBufferIOSurfacePropertiesKey: NSDictionary()])
    }

    public func makePixelBuffer(allocationThreshold: Int) throws -> CVPixelBuffer {
        var allocationThreshold = allocationThreshold
        if allocationThreshold == 0 {
            allocationThreshold = minimumBufferCount
        }
        var pixelBuffer: CVPixelBuffer?
        let err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
            kCFAllocatorDefault,
            pool,
            [
                kCVPixelBufferPoolAllocationThresholdKey as String: allocationThreshold,
            ] as CFDictionary,
            &pixelBuffer
        )
        if err != kCVReturnSuccess {
            if err == kCVReturnWouldExceedAllocationThreshold {
                MTICVPixelBufferPoolIsOutOfBuffer(self)
            }
            throw MTIError.cvPixelBufferPoolError(err)
        }
        guard let pixelBuffer else {
            throw MTIError.cvPixelBufferPoolError(kCVReturnPoolAllocationFailed)
        }
        return pixelBuffer
    }

    public func flush(_ flags: CVPixelBufferPoolFlushFlags) {
        CVPixelBufferPoolFlush(pool, flags)
    }
}
