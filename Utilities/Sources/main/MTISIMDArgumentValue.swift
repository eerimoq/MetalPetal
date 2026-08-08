//
//  MTISIMDArgumentValue.swift
//
//
//  Created by YuAo on 2020/7/11.
//

import Foundation
import SIMDType

private func caseName(for simdType: SIMDType) -> String {
    let scalar = simdType.scalarType.description(capitalized: false)
    switch simdType.dimension {
    case let .vector(count):
        return "\(scalar)\(count)"
    case let .matrix(c, r):
        return "\(scalar)\(c)x\(r)"
    }
}

private func swiftTypeName(for simdType: SIMDType) -> String {
    switch simdType.dimension {
    case let .vector(count):
        "SIMD\(count)<\(simdType.scalarType.swiftTypeName)>"
    case .matrix:
        caseName(for: simdType)
    }
}

func generateMtiSimdArgumentValue() -> [String: String] {
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
    let fileContent = """
    //
    // This is an auto-generated source file.
    //

    import Foundation
    import Metal
    import simd

    public enum MTISIMDArgumentValue {
    \(cases)

        public var dataType: MTLDataType {
            switch self {
    \(dataTypes)
            }
        }

        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            switch self {
    \(bytes)
            }
        }
    }

    """
    return ["MTISIMDArgumentValue.swift": fileContent]
}
