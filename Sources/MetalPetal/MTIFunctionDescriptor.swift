//
//  MTIFunctionDescriptor.swift
//  MetalPetal
//
//  Created by YuAo on 25/06/2017.
//

import Foundation
import Metal

public final class MTIFunctionDescriptor: NSObject, NSCopying {
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

        super.init()
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

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    override public var hash: Int {
        cachedHashValue
    }

    override public func isEqual(_ object: Any?) -> Bool {
        if object as AnyObject === self {
            return true
        }
        guard let descriptor = object as? MTIFunctionDescriptor else {
            return false
        }
        return descriptor.name == name
            && descriptor.libraryURL == libraryURL
            && ((descriptor.constantValues == nil && constantValues == nil)
                || descriptor.constantValues?.isEqual(constantValues) == true)
    }

    override public var description: String {
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
