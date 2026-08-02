//
//  MTISIMDArgumentValue.swift
//  MetalPetal
//
//  Auto-generated.
//

import Foundation
import Metal

/// A SIMD vector or matrix value that can be encoded into a shader function argument.
public enum MTISIMDArgumentValue {
    case float2(SIMD2<Float>)
    case float3(SIMD3<Float>)
    case float4(SIMD4<Float>)
    case float2x2(float2x2)
    case float2x3(float2x3)
    case float2x4(float2x4)
    case float3x2(float3x2)
    case float3x3(float3x3)
    case float3x4(float3x4)
    case float4x2(float4x2)
    case float4x3(float4x3)
    case float4x4(float4x4)
    case int2(SIMD2<Int32>)
    case int3(SIMD3<Int32>)
    case int4(SIMD4<Int32>)
    case uint2(SIMD2<UInt32>)
    case uint3(SIMD3<UInt32>)
    case uint4(SIMD4<UInt32>)
    case short2(SIMD2<Int16>)
    case short3(SIMD3<Int16>)
    case short4(SIMD4<Int16>)
    case ushort2(SIMD2<UInt16>)
    case ushort3(SIMD3<UInt16>)
    case ushort4(SIMD4<UInt16>)
    case char2(SIMD2<Int8>)
    case char3(SIMD3<Int8>)
    case char4(SIMD4<Int8>)
    case uchar2(SIMD2<UInt8>)
    case uchar3(SIMD3<UInt8>)
    case uchar4(SIMD4<UInt8>)
    #if !os(tvOS)
    case packedFloat3(MTLPackedFloat3)
    #endif

    /// The data type a shader argument must be declared with to accept this value.
    public var dataType: MTLDataType {
        switch self {
        case .float2:
            .float2
        case .float3:
            .float3
        case .float4:
            .float4
        case .float2x2:
            .float2x2
        case .float2x3:
            .float2x3
        case .float2x4:
            .float2x4
        case .float3x2:
            .float3x2
        case .float3x3:
            .float3x3
        case .float3x4:
            .float3x4
        case .float4x2:
            .float4x2
        case .float4x3:
            .float4x3
        case .float4x4:
            .float4x4
        case .int2:
            .int2
        case .int3:
            .int3
        case .int4:
            .int4
        case .uint2:
            .uint2
        case .uint3:
            .uint3
        case .uint4:
            .uint4
        case .short2:
            .short2
        case .short3:
            .short3
        case .short4:
            .short4
        case .ushort2:
            .ushort2
        case .ushort3:
            .ushort3
        case .ushort4:
            .ushort4
        case .char2:
            .char2
        case .char3:
            .char3
        case .char4:
            .char4
        case .uchar2:
            .uchar2
        case .uchar3:
            .uchar3
        case .uchar4:
            .uchar4
        #if !os(tvOS)
        case .packedFloat3:
            .float3
        #endif
        }
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        switch self {
        case let .float2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float2x2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float2x3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float2x4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float3x2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float3x3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float3x4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float4x2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float4x3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .float4x4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .int2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .int3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .int4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .uint2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .uint3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .uint4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .short2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .short3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .short4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .ushort2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .ushort3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .ushort4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .char2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .char3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .char4(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .uchar2(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .uchar3(value):
            try Swift.withUnsafeBytes(of: value, body)
        case let .uchar4(value):
            try Swift.withUnsafeBytes(of: value, body)
        #if !os(tvOS)
        case let .packedFloat3(value):
            try Swift.withUnsafeBytes(of: value, body)
        #endif
        }
    }
}
