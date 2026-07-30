//
//  MTIFunctionDescriptor.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/12/26.
//

import Foundation

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
