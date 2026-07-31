//
//  MTISIMDArgumentEncoder.swift
//  MetalPetal
//
//  Auto-generated.
//

import Foundation
import Metal

public enum MTISIMDArgumentEncoder: MTIFunctionArgumentEncoding {
    public enum Error: String, Swift.Error, LocalizedError {
        case argumentTypeMismatch
        public var errorDescription: String? {
            rawValue
        }
    }

    public static func encodeValue(
        _ value: Any,
        binding: any MTLBufferBinding,
        proxy: MTIFunctionArgumentEncodingProxy
    ) throws {
        switch value {
        case let v as SIMD2<Float>:
            guard binding.bufferDataType == .float2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD3<Float>:
            guard binding.bufferDataType == .float3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD4<Float>:
            guard binding.bufferDataType == .float4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float2x2:
            guard binding.bufferDataType == .float2x2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float2x3:
            guard binding.bufferDataType == .float2x3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float2x4:
            guard binding.bufferDataType == .float2x4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float3x2:
            guard binding.bufferDataType == .float3x2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float3x3:
            guard binding.bufferDataType == .float3x3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float3x4:
            guard binding.bufferDataType == .float3x4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float4x2:
            guard binding.bufferDataType == .float4x2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float4x3:
            guard binding.bufferDataType == .float4x3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as float4x4:
            guard binding.bufferDataType == .float4x4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD2<Int32>:
            guard binding.bufferDataType == .int2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD3<Int32>:
            guard binding.bufferDataType == .int3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD4<Int32>:
            guard binding.bufferDataType == .int4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD2<UInt32>:
            guard binding.bufferDataType == .uint2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD3<UInt32>:
            guard binding.bufferDataType == .uint3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD4<UInt32>:
            guard binding.bufferDataType == .uint4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD2<Int16>:
            guard binding.bufferDataType == .short2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD3<Int16>:
            guard binding.bufferDataType == .short3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD4<Int16>:
            guard binding.bufferDataType == .short4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD2<UInt16>:
            guard binding.bufferDataType == .ushort2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD3<UInt16>:
            guard binding.bufferDataType == .ushort3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD4<UInt16>:
            guard binding.bufferDataType == .ushort4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD2<Int8>:
            guard binding.bufferDataType == .char2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD3<Int8>:
            guard binding.bufferDataType == .char3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD4<Int8>:
            guard binding.bufferDataType == .char4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD2<UInt8>:
            guard binding.bufferDataType == .uchar2 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD3<UInt8>:
            guard binding.bufferDataType == .uchar3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        case let v as SIMD4<UInt8>:
            guard binding.bufferDataType == .uchar4 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        #if !os(tvOS)
        case let v as MTLPackedFloat3:
            guard binding.bufferDataType == .float3 else {
                throw Error.argumentTypeMismatch
            }
            encode(v, proxy: proxy)
        #endif
        default:
            break
        }
    }

    private static func encode(_ value: some Any, proxy: MTIFunctionArgumentEncodingProxy) {
        withUnsafePointer(to: value) { ptr in
            proxy.encodeBytes(ptr, length: MemoryLayout.size(ofValue: value))
        }
    }
}
