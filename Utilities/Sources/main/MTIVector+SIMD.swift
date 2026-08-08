import Foundation
import SIMDType

extension SIMDType {
    var getterForMTIVector: String {
        switch dimension {
        case let .vector(c):
            "\(scalarType.description(capitalized: false))\(c)"
        case let .matrix(c, r):
            "\(scalarType.description(capitalized: false))\(c)x\(r)"
        }
    }

    /// The label of the `MTIVector` designated initializer for this type's scalar, e.g. `floatValues`.
    var scalarValuesInitializerLabel: String {
        "\(scalarType.description(capitalized: false))Values"
    }

    /// The Swift name of the `MTIVector.ScalarType` case for this type's scalar, e.g. `float`.
    var scalarTypeCaseName: String {
        scalarType.description(capitalized: false)
    }

    /// The Swift simd type name, e.g. `simd_float2` / `simd_float3x3`.
    var swiftSIMDTypeName: String {
        description(prefix: "simd_")
    }
}

func generateMtiVectorSimd() -> [String: String] {
    var lines: [String] = []
    for type in SIMDType.metalSupportedSIMDTypes {
        let swiftType = type.swiftSIMDTypeName
        let scalarType = type.scalarType.swiftTypeName
        lines.append("""
        public init(value: \(swiftType)) {
            var v = value
            let count = MemoryLayout<\(swiftType)>.size / MemoryLayout<\(scalarType)>.size
            let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: \(
                scalarType
            ).self)) }
            self.init(\(type.scalarValuesInitializerLabel): scalars, count: count)
        }

        public func \(type.getterForMTIVector)() -> \(swiftType) {
            var value = \(swiftType)()
            if scalarType == .\(type
            .scalarTypeCaseName) && byteLength == MemoryLayout<\(swiftType)>.size {
                withUnsafeBytes { source in
                    _ = Swift.withUnsafeMutableBytes(of: &value) {
                        memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<\(
                            swiftType
                        )>.size) }
                }
            }
            return value
        }
        """)
    }
    let fileContent = """
    //
    // This is an auto-generated source file.
    //

    import Foundation
    import simd

    extension MTIVector {

    \(lines.joined(separator: "\n\n"))
    }
    """
    return [
        "MTIVector+SIMD.swift": fileContent,
    ]
}
