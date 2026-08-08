//
//  MTISIMDArgumentValue.swift
//
//
//  Created by YuAo on 2020/7/11.
//

import Foundation
import SIMDType

private let template: String = """
//
//  MTISIMDArgumentValue.swift
//  MetalPetal
//
//  Auto-generated.
//

import Foundation
import Metal
import simd

/// A SIMD vector or matrix value that can be encoded into a shader function argument.
public enum MTISIMDArgumentValue {
{MTI_SIMD_ARGUMENT_VALUE_CASES}

    /// The data type a shader argument must be declared with to accept this value.
    public var dataType: MTLDataType {
        switch self {
{MTI_SIMD_ARGUMENT_VALUE_DATA_TYPES}
        }
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        switch self {
{MTI_SIMD_ARGUMENT_VALUE_BYTES}
        }
    }
}

"""

public enum MTISIMDArgumentValueGenerator {
    private static func caseName(for simdType: SIMDType) -> String {
        let scalar = simdType.scalarType.description(capitalized: false)
        switch simdType.dimension {
        case let .vector(count):
            return "\(scalar)\(count)"
        case let .matrix(c, r):
            return "\(scalar)\(c)x\(r)"
        }
    }

    private static func swiftTypeName(for simdType: SIMDType) -> String {
        switch simdType.dimension {
        case let .vector(count):
            "SIMD\(count)<\(simdType.scalarType.swiftTypeName)>"
        case .matrix:
            caseName(for: simdType)
        }
    }

    public static func generate() -> [String: String] {
        var cases = ""
        var dataTypes = ""
        var bytes = ""
        for simdType in SIMDType.metalSupportedSIMDTypes {
            let name = caseName(for: simdType)
            let type = swiftTypeName(for: simdType)
            cases.append("case \(name)(\(type))\n")
            dataTypes.append("case .\(name):\n.\(name)\n")
            bytes.append("case let .\(name)(value):\ntry Swift.withUnsafeBytes(of: value, body)\n")
        }
        // `packed_float3` shares its data type with `float3`; the two are told apart by their size.
        cases.append("""
        #if !os(tvOS)
            case packedFloat3(MTLPackedFloat3)
        #endif
        """)
        dataTypes.append("""
        #if !os(tvOS)
                case .packedFloat3:
                .float3
        #endif
        """)
        bytes.append("""
        #if !os(tvOS)
                case let .packedFloat3(value):
                try Swift.withUnsafeBytes(of: value, body)
        #endif
        """)
        let content = template
            .replacingOccurrences(of: "{MTI_SIMD_ARGUMENT_VALUE_CASES}", with: cases)
            .replacingOccurrences(of: "{MTI_SIMD_ARGUMENT_VALUE_DATA_TYPES}", with: dataTypes)
            .replacingOccurrences(of: "{MTI_SIMD_ARGUMENT_VALUE_BYTES}", with: bytes)
        return ["MTISIMDArgumentValue.swift": content]
    }
}
