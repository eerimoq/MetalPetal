// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Utilities",
    platforms: [.macOS(.v14)],
    products: [],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"),
        .package(url: "https://github.com/MetalPetal/SIMDType.git", from: "0.0.3"),
    ],
    targets: [
        .target(
            name: "BoilerplateGenerator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SIMDType",
                "URLExpressibleByArgument",
                "MetalPetalSourceLocator",
            ]
        ),
        .target(
            name: "URLExpressibleByArgument",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(name: "MetalPetalSourceLocator"),
        .executableTarget(
            name: "main",
            dependencies: ["BoilerplateGenerator"]
        ),
    ]
)
