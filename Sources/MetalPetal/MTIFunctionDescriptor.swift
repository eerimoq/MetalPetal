//
//  MTIFunctionDescriptor.swift
//  MetalPetal
//
//  Created by YuAo on 25/06/2017.
//

import Foundation
import Metal

public final class MTIFunctionDescriptor: Hashable, CustomStringConvertible {
    public let libraryURL: URL?

    public let name: String

    public let constantValues: MTLFunctionConstantValues?

    private let cachedHashValue: Int

    public init(name: String, constantValues: MTLFunctionConstantValues?, libraryURL: URL?) {
        self.name = name
        self.libraryURL = libraryURL
        self.constantValues = constantValues?.copy() as? MTLFunctionConstantValues

        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(libraryURL)
        hasher.combine(self.constantValues)
        cachedHashValue = hasher.finalize()
    }

    public convenience init(name: String) {
        self.init(name: name, constantValues: nil, libraryURL: nil)
    }

    public convenience init(name: String, libraryURL: URL?) {
        self.init(name: name, constantValues: nil, libraryURL: libraryURL)
    }

    public func withConstantValues(_ constantValues: MTLFunctionConstantValues?) -> MTIFunctionDescriptor {
        MTIFunctionDescriptor(name: name, constantValues: constantValues, libraryURL: libraryURL)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cachedHashValue)
    }

    public static func == (lhs: MTIFunctionDescriptor, rhs: MTIFunctionDescriptor) -> Bool {
        if lhs === rhs {
            return true
        }
        return lhs.name == rhs.name
            && lhs.libraryURL == rhs.libraryURL
            && ((lhs.constantValues == nil && rhs.constantValues == nil)
                || lhs.constantValues?.isEqual(rhs.constantValues) == true)
    }

    public var description: String {
        "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque()); "
            + "name = \(name); constantValues = \(String(describing: constantValues)); "
            + "libraryURL = \(String(describing: libraryURL))>"
    }
}

public extension MTIFunctionDescriptor {
    static let passthroughFragment: MTIFunctionDescriptor =
        .init(name: MTIFilterPassthroughFragmentFunctionName)

    static let passthroughVertex: MTIFunctionDescriptor = .init(name: MTIFilterPassthroughVertexFunctionName)
}

public extension MTIFunctionDescriptor {
    convenience init(name: String, constantValues: MTLFunctionConstantValues? = nil, in bundle: Bundle) {
        self.init(
            name: name,
            constantValues: constantValues,
            libraryURL: MTIDefaultLibraryURLForBundle(bundle)
        )
    }
}

public extension URL {
    static func defaultMetalLibraryURL(for bundleForClass: AnyClass) -> URL! {
        MTIDefaultLibraryURLForBundle(Bundle(for: bundleForClass))
    }

    static func defaultMetalLibraryURL(for bundle: Bundle) -> URL! {
        MTIDefaultLibraryURLForBundle(bundle)
    }
}
