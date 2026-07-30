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
        let sourcesDirectory = MetalPetalSourcesRootURL(in: projectRoot)
        let packageSourcesDirectory = projectRoot.appendingPathComponent("Sources/")
        try? fileManager.removeItem(at: packageSourcesDirectory)
        try fileManager.createDirectory(at: packageSourcesDirectory, withIntermediateDirectories: true, attributes: nil)
        let swiftTargetDirectory = packageSourcesDirectory.appendingPathComponent("MetalPetal/")
        try fileManager.createDirectory(at: swiftTargetDirectory, withIntermediateDirectories: true, attributes: nil)

        // MetalPetal is now an all-Swift target; only `.swift` sources are mirrored into the package. The
        // shader source headers (Shaders/MTIShaderLib.h etc.) stay in the authoritative Frameworks tree and
        // are read directly when generating the builtin library support code below.
        let fileHandlers = [
            SourceFileHandler(fileTypes: ["swift"], projectRoot: projectRoot, targetURL: swiftTargetDirectory, fileManager: fileManager)
        ]

        try processSources(in: sourcesDirectory, fileHandlers: fileHandlers)

        try generateBuiltinMetalLibrarySupportCode(swiftTargetDirectory: swiftTargetDirectory, shadersDirectory: sourcesDirectory.appendingPathComponent("Shaders"))
    }
    
    public func generateBuiltinMetalLibrarySupportCode(swiftTargetDirectory: URL, shadersDirectory: URL) throws {
        let source = try collectBuiltinMetalLibrarySource(shadersDirectory: shadersDirectory)
        // The shader source is embedded verbatim using a raw string literal (`#"""..."""#`), so it needs no
        // escaping. `\##(source)` is the interpolation for the outer `##"""..."""##` raw string.
        let generatedSwift = ##"""
        // Auto generated.
        import Foundation
        import Metal

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
    
    private func processSources(in directory: URL, fileHandlers: [SourceFileHandler]) throws {
        let sourceFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for sourceFile in sourceFiles {
            if try sourceFile.resourceValues(forKeys: Set<URLResourceKey>([URLResourceKey.isDirectoryKey])).isDirectory == true {
                try processSources(in: sourceFile, fileHandlers: fileHandlers)
            } else {
                for fileHandler in fileHandlers {
                    try fileHandler.handle(sourceFile)
                }
            }
        }
    }
    
    struct SourceFileHandler {
        let fileTypes: [String]
        let projectRoot: URL
        let targetURL: URL
        let fileManager: FileManager
        
        enum Error: String, Swift.Error, LocalizedError {
            case cannotCreateRelativePath
            var errorDescription: String? {
                return self.rawValue
            }
        }
        
        @discardableResult func handle(_ file: URL) throws -> Bool {
            if fileTypes.contains(file.pathExtension) || fileTypes.contains(file.lastPathComponent) {
                let fileRelativeToProjectRoot = try relativePathComponents(for: file, baseURL: projectRoot)
                let targetRelativeToProjectRoot = try relativePathComponents(for: targetURL, baseURL: projectRoot)
                let destinationURL = URL(string: (Array<String>(repeating: "..", count: targetRelativeToProjectRoot.count) + fileRelativeToProjectRoot).joined(separator: "/"))!
                try fileManager.createSymbolicLink(at: targetURL.appendingPathComponent(file.lastPathComponent), withDestinationURL: destinationURL)
                return true
            } else {
                return false
            }
        }
        
        private func relativePathComponents(for url: URL, baseURL: URL) throws -> [String] {
            let filePathComponents = url.standardized.pathComponents
            let basePathComponents = baseURL.standardized.pathComponents
            let r: [String] = filePathComponents.dropLast(filePathComponents.count - basePathComponents.count)
            if r == basePathComponents {
                return [String](filePathComponents.dropFirst(basePathComponents.count))
            } else {
                throw Error.cannotCreateRelativePath
            }
        }
    }
}
