//
//  LibrarySource.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/5/7.
//

import Foundation
import Metal
import os

public let MTIURLSchemeForLibraryWithSource = "mti.library-source"

private func urlForLibrarySource(_ identifier: String) -> URL {
    var components = URLComponents()
    components.scheme = MTIURLSchemeForLibraryWithSource
    components.host = "shared"
    components.queryItems = [URLQueryItem(name: "id", value: identifier)]
    return components.url!
}

private final class LibrarySource {
    let source: String
    let compileOptions: MTLCompileOptions?

    init(source: String, compileOptions: MTLCompileOptions?) {
        self.source = source
        self.compileOptions = compileOptions?.copy() as? MTLCompileOptions
    }
}

/// `MTILibrarySourceRegistration` can be used under the situation where it is impossible to use an offline
/// metal compiler. You should avoid using this class as much as you can.
public final class MTILibrarySourceRegistration {
    private var sources: [URL: LibrarySource] = [:]
    private let lock = OSAllocatedUnfairLock()
    public static let shared = MTILibrarySourceRegistration()

    private init() {}

    /// Returns a URL representing the metal library compiled with the `source` code. This URL can be used in
    /// `MTIFunctionDescriptor(name:libraryURL:)`.
    public func registerLibrary(source: String, compileOptions: MTLCompileOptions?) -> URL {
        let identifier = UUID().uuidString
        let url = urlForLibrarySource(identifier)
        let librarySource = LibrarySource(source: source, compileOptions: compileOptions)
        lock.lock()
        sources[url] = librarySource
        lock.unlock()
        return url
    }

    public func unregisterLibrary(with url: URL) {
        lock.lock()
        sources[url] = nil
        lock.unlock()
    }

    public func newLibrary(with libraryURL: URL, device: MTLDevice) throws -> MTLLibrary {
        lock.lock()
        let librarySource = sources[libraryURL]
        lock.unlock()
        guard let librarySource else {
            throw MTIError.libraryNotFound
        }
        return try device.makeLibrary(source: librarySource.source, options: librarySource.compileOptions)
    }
}
