import Foundation
import ArgumentParser
import URLExpressibleByArgument
import MetalPetalSourceLocator

public struct SwiftPackageGenerator: ParsableCommand {
    
    @Argument(help: "The root directory of the MetalPetal repo.")
    var projectRoot: URL
    
    enum CodingKeys: CodingKey {
        case projectRoot
    }
    
    private let fileManager = FileManager()

    public init() { }
    
    public func run() throws {
        // MetalPetal is a single all-Swift SwiftPM target living at `Sources/MetalPetal`, so there is no
        // longer a separate source tree to mirror. This step only regenerates the builtin metal library
        // support code (the embedded shader source), reading the shaders in place.
        let sourcesDirectory = MetalPetalSourcesRootURL(in: projectRoot)
        try generateBuiltinMetalLibrarySupportCode(
            swiftTargetDirectory: sourcesDirectory,
            shadersDirectory: sourcesDirectory.appendingPathComponent("Shaders")
        )
    }
    
    public func generateBuiltinMetalLibrarySupportCode(swiftTargetDirectory: URL, shadersDirectory: URL) throws {
        let source = try collectBuiltinMetalLibrarySource(shadersDirectory: shadersDirectory)
        // The shader source is embedded verbatim using a raw string literal (`#"""..."""#`), so it needs no
        // escaping. `\##(source)` is the interpolation for the outer `##"""..."""##` raw string.
        let generatedSwift = ##"""
        // Auto generated.
        import Foundation
        import Metal

        // swiftlint:disable line_length
        // swiftlint:disable trailing_whitespace

        private let MTIBuiltinLibrarySource = #"""
        \##(source)
        """#

        func _MTISwiftPMBuiltinLibrarySourceURL() -> URL {
            enum Static {
                static let url: URL = {
                    #if targetEnvironment(simulator)
                    let targetConditionals = "#ifndef TARGET_OS_SIMULATOR\n#define TARGET_OS_SIMULATOR 1\n#endif"
                    #else
                    let targetConditionals = "#ifndef TARGET_OS_SIMULATOR\n#define TARGET_OS_SIMULATOR 0\n#endif"
                    #endif
                    let librarySource = targetConditionals + MTIBuiltinLibrarySource
                    let options = MTLCompileOptions()
                    options.fastMathEnabled = true
                    return MTILibrarySourceRegistration.shared.registerLibrary(source: librarySource, compileOptions: options)
                }()
            }
            return Static.url
        }

        // swiftlint:enable trailing_whitespace
        // swiftlint:enable line_length

        """##
        try generatedSwift.write(
            to: swiftTargetDirectory.appendingPathComponent("MTISwiftPMBuiltinLibrarySupport.swift"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    public func collectBuiltinMetalLibrarySource(shadersDirectory: URL) throws -> String {
        var librarySource = ""
        let sourceFileDirectory = shadersDirectory
        librarySource += try String(contentsOf: sourceFileDirectory.appendingPathComponent("MTIShaderLib.h"))
        librarySource += try String(contentsOf: sourceFileDirectory.appendingPathComponent("MTIShaderFunctionConstants.h"))
        let fileManager = FileManager()
        for source in try fileManager.contentsOfDirectory(at: sourceFileDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if source.pathExtension == "metal" {
                librarySource += "\n"
                librarySource += try String(contentsOf: source)
                    .replacingOccurrences(of: "#include \"MTIShaderLib.h\"", with: "\n")
                    .replacingOccurrences(of: "#include \"MTIShaderFunctionConstants.h\"", with: "\n")
                    .replacingOccurrences(of: "#include <TargetConditionals.h>", with: "\n")
            }
        }
        return librarySource
    }
    
}
