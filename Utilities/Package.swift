// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Utilities",
    platforms: [.macOS(.v14)],
    products: [],
    dependencies: [
        .package(url: "https://github.com/MetalPetal/SIMDType.git", from: "0.0.3"),
    ],
    targets: [
        .executableTarget(
            name: "main",
            dependencies: ["SIMDType"]
        ),
    ]
)
