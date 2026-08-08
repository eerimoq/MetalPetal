//
//  SIMDTypeNaming.swift
//

import SIMDType

extension SIMDType {
    var unprefixedName: String {
        description(prefix: "")
    }

    var swiftSIMDTypeName: String {
        description()
    }

    var argumentValueTypeName: String {
        switch dimension {
        case let .vector(count):
            "SIMD\(count)<\(scalarType.swiftTypeName)>"
        case .matrix:
            unprefixedName
        }
    }

    var scalarTypeCaseName: String {
        scalarType.description(capitalized: false)
    }

    var scalarValuesInitializerLabel: String {
        "\(scalarTypeCaseName)Values"
    }
}
