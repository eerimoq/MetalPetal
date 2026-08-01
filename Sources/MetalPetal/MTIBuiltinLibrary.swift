//
//  MTIBuiltinLibrary.swift
//  MetalPetal
//

import Foundation
import Metal

func MTIBuiltinLibraryURL() -> URL {
    enum Static {
        static let url: URL = MTIDefaultLibraryURLForBundle(.module) ?? MTIBuiltinLibrarySourceURL()
    }
    return Static.url
}

private func MTIBuiltinLibrarySourceURL() -> URL {
    let options = MTLCompileOptions()
    options.fastMathEnabled = true
    return MTILibrarySourceRegistration.shared.registerLibrary(
        source: MTIBuiltinLibrarySource(),
        compileOptions: options
    )
}

private func MTIBuiltinLibrarySource() -> String {
    let bundle = Bundle.module
    guard let metalSourceURLs = bundle.urls(forResourcesWithExtension: "metal", subdirectory: nil),
          !metalSourceURLs.isEmpty
    else {
        return """
        #error "MetalPetal found neither a compiled `default.metallib` nor any shader source in its \
        resource bundle at \(bundle.bundleURL.path)."
        """
    }
    #if targetEnvironment(simulator)
    let targetConditionals = "#ifndef TARGET_OS_SIMULATOR\n#define TARGET_OS_SIMULATOR 1\n#endif\n"
    #else
    let targetConditionals = "#ifndef TARGET_OS_SIMULATOR\n#define TARGET_OS_SIMULATOR 0\n#endif\n"
    #endif
    var source = targetConditionals
    for header in ["MTIShaderLib", "MTIShaderFunctionConstants"] {
        guard let url = bundle.url(forResource: header, withExtension: "h"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            continue
        }
        source += contents
    }
    for url in metalSourceURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            continue
        }
        source += "\n"
        source += contents
            .replacingOccurrences(of: "#include \"MTIShaderLib.h\"", with: "\n")
            .replacingOccurrences(of: "#include \"MTIShaderFunctionConstants.h\"", with: "\n")
            .replacingOccurrences(of: "#include <TargetConditionals.h>", with: "\n")
    }
    return source
}
