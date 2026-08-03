// swift-tools-version:5.9

// requires SE-0271

import PackageDescription

let package = Package(
    name: "MetalPetal",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16)],
    products: [
        .library(
            name: "MetalPetal",
            targets: ["MetalPetal", "MetalPetalShaderTypes"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MetalPetalShaderTypes",
            path: "Sources/MetalPetalShaderTypes",
            publicHeadersPath: "include"),
        .target(
            name: "MetalPetal",
            dependencies: [],
            resources: [.process("Shaders")]),
        .target(
            name: "MetalPetalTestHelpers",
            dependencies: ["MetalPetal"],
            path: "Tests/MetalPetalTestHelpers"),
        .testTarget(
            name: "MetalPetalTests",
            dependencies: ["MetalPetal", "MetalPetalTestHelpers"]),
        .testTarget(
            name: "MetalPetalPublicApiTests",
            dependencies: ["MetalPetal"]),
    ]
)
