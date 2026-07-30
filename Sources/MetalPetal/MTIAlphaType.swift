//
//  MTIAlphaType.swift
//  MetalPetal
//
//  Created by Yu Ao on 23/10/2017.
//

import Foundation

/// Describe different ways to represent the opacity of a color value. See also:
/// https://microsoft.github.io/Win2D/html/PremultipliedAlpha.htm
public enum MTIAlphaType: Int {
    /// The alpha type is unknown.
    case unknown = 0
    /// RGB values specify the color of the thing being drawn. The alpha value specifies how solid it is.
    case nonPremultiplied = 1
    /// RGB specifies how much color the thing being drawn contributes to the output. The alpha value
    /// specifies how much it obscures whatever is behind it.
    case premultiplied = 2
    /// There is no alpha channel or the alpha value is one.
    case alphaIsOne = 3
}

public func MTIAlphaTypeGetDescription(_ alphaType: MTIAlphaType) -> String {
    switch alphaType {
    case .premultiplied:
        "Premultiplied"
    case .nonPremultiplied:
        "NonPremultiplied"
    case .alphaIsOne:
        "AlphaIsOne"
    case .unknown:
        "UnknownAlphaType"
    }
}

extension MTIAlphaType: CustomStringConvertible {
    public var description: String {
        MTIAlphaTypeGetDescription(self)
    }
}

public typealias MTIAlphaTypeHandlingOutputAlphaTypeRule = ([MTIAlphaType]) -> MTIAlphaType

/// Describes how a image processing unit handles alpha types.
public final class MTIAlphaTypeHandlingRule: NSObject, NSCopying {
    /// Acceptable alpha types.
    public let acceptableAlphaTypes: [MTIAlphaType]
    private let outputAlphaTypeHandler: MTIAlphaTypeHandlingOutputAlphaTypeRule?
    private let outputAlphaTypeValue: MTIAlphaType

    public init(
        acceptableAlphaTypes: [MTIAlphaType],
        outputAlphaTypeHandler: @escaping MTIAlphaTypeHandlingOutputAlphaTypeRule
    ) {
        self.acceptableAlphaTypes = acceptableAlphaTypes
        self.outputAlphaTypeHandler = outputAlphaTypeHandler
        outputAlphaTypeValue = .unknown
        super.init()
    }

    public init(acceptableAlphaTypes: [MTIAlphaType], outputAlphaType: MTIAlphaType) {
        self.acceptableAlphaTypes = acceptableAlphaTypes
        outputAlphaTypeHandler = nil
        outputAlphaTypeValue = outputAlphaType
        super.init()
    }

    public convenience init(
        acceptableAlphaTypes: [MTIAlphaType],
        _ handler: @escaping ([MTIAlphaType]) -> MTIAlphaType
    ) {
        self.init(acceptableAlphaTypes: acceptableAlphaTypes, outputAlphaTypeHandler: handler)
    }

    public convenience init(_ handler: @escaping ([MTIAlphaType]) -> MTIAlphaType) {
        self.init(
            acceptableAlphaTypes: [.premultiplied, .nonPremultiplied, .alphaIsOne],
            outputAlphaTypeHandler: handler
        )
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    public func canAcceptAlphaType(_ alphaType: MTIAlphaType) -> Bool {
        acceptableAlphaTypes.contains(alphaType)
    }

    public func outputAlphaType(forInputAlphaTypes inputAlphaTypes: [MTIAlphaType]) -> MTIAlphaType {
        if let handler = outputAlphaTypeHandler {
            handler(inputAlphaTypes)
        } else {
            outputAlphaTypeValue
        }
    }

    public func outputAlphaType(forInputImages inputImages: [MTIImage]) -> MTIAlphaType {
        if let handler = outputAlphaTypeHandler {
            let alphaTypes = inputImages.map(\.alphaType)
            assert(Set(alphaTypes).isSubset(of: Set(acceptableAlphaTypes)))
            return handler(alphaTypes)
        } else {
            return outputAlphaTypeValue
        }
    }

    /// Accepts MTIAlphaTypeNonPremultiplied and MTIAlphaTypeAlphaIsOne. Outputs MTIAlphaTypeNonPremultiplied.
    public static let general = MTIAlphaTypeHandlingRule(
        acceptableAlphaTypes: [.nonPremultiplied, .alphaIsOne],
        outputAlphaType: .nonPremultiplied
    )

    /// Accepts all alpha types. The output alpha type is the same as input alpha type.
    public static let passthrough = MTIAlphaTypeHandlingRule(acceptableAlphaTypes: [
        .nonPremultiplied,
        .alphaIsOne,
        .premultiplied,
    ]) { inputAlphaTypes in
        assert(Set(inputAlphaTypes).count == 1)
        return inputAlphaTypes.first ?? .unknown
    }

    public func _canHandleAlphaTypes(in images: [MTIImage]) -> Bool {
        /* Alpha Type Assert */
        // https://github.com/MetalPetal/MetalPetal#alpha-types
        for image in images where !canAcceptAlphaType(image.alphaType) {
            return false
        }
        return true
    }
}
