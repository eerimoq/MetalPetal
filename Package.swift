// swift-tools-version:5.9

// requires SE-0271

import PackageDescription

let package = Package(
    name: "MetalPetal",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16)],
    products: [
        .library(
            name: "MetalPetal",
            targets: ["MetalPetal"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MetalPetal",
            dependencies: [],
            // The Shaders directory holds .metal source + shared C headers. They are compiled at runtime
            // from the embedded builtin library (MTISwiftPMBuiltinLibrarySupport.swift), not by SwiftPM.
            exclude: ["Shaders"]),
        .target(
            name: "MetalPetalTestHelpers",
            dependencies: ["MetalPetal"],
            path: "Tests/MetalPetalTestHelpers"),
        .testTarget(
            name: "MetalPetalTests",
            dependencies: ["MetalPetal", "MetalPetalTestHelpers"]),
    ]
)
