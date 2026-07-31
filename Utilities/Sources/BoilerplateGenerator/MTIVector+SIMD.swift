import Foundation
import SIMDType

extension SIMDType {

    var getterForMTIVector: String {
        switch self.dimension {
        case .vector(let c):
            return "\(self.scalarType.description(capitalized: false))\(c)Value"
        case .matrix(let c, let r):
            return "\(self.scalarType.description(capitalized: false))\(c)x\(r)Value"
        }
    }

    /// The label of the `MTIVector` designated initializer for this type's scalar, e.g. `floatValues`.
    var scalarValuesInitializerLabel: String {
        return "\(self.scalarType.description(capitalized: false))Values"
    }

    /// The Swift name of the `MTIVector.ScalarType` case for this type's scalar, e.g. `float`.
    var scalarTypeCaseName: String {
        return self.scalarType.description(capitalized: false)
    }

    /// The Swift simd type name, e.g. `simd_float2` / `simd_float3x3`.
    var swiftSIMDTypeName: String {
        return self.description(prefix: "simd_")
    }
}

public struct MTIVectorSIMDTypeSupportCodeGenerator {

    struct SwiftTemplate {
        private let template =
        """
        //
        //  MTIVector+SIMD.swift
        //  MetalPetal
        //
        //  Created by Yu Ao on 2018/6/30.
        //
        //  Auto generated.

        import Foundation
        import simd
        // WARNING: MTIVector equality may not work for a MTIVector holding a simd_type3 or simd_typeNx3 value.

        extension MTIVector {

        {MTIVectorSIMDSupport}
        }

        """

        private var lines: [String] = []

        mutating func append(type: SIMDType) {
            let swiftType = type.swiftSIMDTypeName
            let scalarType = type.scalarType.swiftTypeName
            lines.append(
                """
                    public convenience init(value: \(swiftType)) {
                        var v = value
                        let count = MemoryLayout<\(swiftType)>.size / MemoryLayout<\(scalarType)>.size
                        let scalars: [\(scalarType)] = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: \(scalarType).self)) }
                        self.init(\(type.scalarValuesInitializerLabel): scalars, count: count)
                    }

                    public var \(type.getterForMTIVector): \(swiftType) {
                        var value = \(swiftType)()
                        if scalarType == .\(type.scalarTypeCaseName) && byteLength == MemoryLayout<\(swiftType)>.size {
                            withUnsafeBytes { source in
                                _ = Swift.withUnsafeMutableBytes(of: &value) { memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<\(swiftType)>.size) }
                            }
                        }
                        return value
                    }
                """)
        }

        func makeContent() -> String {
            return self.template.replacingOccurrences(of: "{MTIVectorSIMDSupport}", with: self.lines.reduce("", {
                $0.count > 0 ? ($0 + "\n\n" + $1) : $1
            }))
        }
    }

    public static func generate() -> [String: String] {
        var swiftTemplate = SwiftTemplate()

        for type in SIMDType.metalSupportedSIMDTypes {
            swiftTemplate.append(type: type)
        }

        return [
            "MTIVector+SIMD.swift": swiftTemplate.makeContent()
        ]
    }
}
