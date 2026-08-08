//
//  ContextTests.swift
//
//
//  Created by YuAo on 2021/2/2.
//

import CoreImage
import Metal
import MetalKit
import MetalPerformanceShaders
@testable import MetalPetal
import Testing

func listMetalDevices() -> String {
    #if os(macOS)
    let devices = MTLCopyAllDevices()
    return devices.map(\.description).joined(separator: "\n")
    #else
    if let device = MTLCreateSystemDefaultDevice() {
        return device.description
    } else {
        return ""
    }
    #endif
}

let metalDeviceIsAvailable = MTLCreateSystemDefaultDevice() != nil

func makeContext(options: MTIContextOptions? = nil) throws -> MTIContext {
    let device = try #require(MTLCreateSystemDefaultDevice(), "no metal device found.")
    if let options {
        return try MTIContext(device: device, options: options)
    } else {
        return try MTIContext(device: device)
    }
}

@Suite(.enabled(if: metalDeviceIsAvailable))
struct ContextTests {
    @Test func contextCreation() throws {
        print("""
        ----- Metal Devices -----
        \(listMetalDevices())
        -------------------------
        """)
        let context = try makeContext()
        print("""
        ----- Context -----
        isProgrammableBlendingSupported - \(context.isProgrammableBlendingSupported)
        defaultLibrarySupportsProgrammableBlending - \(context.defaultLibrarySupportsProgrammableBlending)
        isMemorylessTextureSupported - \(context.isMemorylessTextureSupported)
        isMetalPerformanceShadersSupported - \(context.isMetalPerformanceShadersSupported)
        isYCbCrPixelFormatSupported - \(context.isYCbCrPixelFormatSupported)
        -------------------
        """)
    }

    @Test func builtinLibrary() throws {
        let isPrecompiled = MTIBuiltinLibraryURL().scheme != MTIURLSchemeForLibraryWithSource
        print("built-in metal library is precompiled - \(isPrecompiled)")
        let context = try makeContext()
        let functionNames = Set(context.defaultLibrary.functionNames)
        for name in [
            "metalpetal::passthroughVertex",
            "metalpetal::passthrough",
            "metalpetal::colorLookup3D",
            "metalpetal::multilayerCompositeNormalBlend",
        ] {
            #expect(functionNames.contains(name))
        }
        #if targetEnvironment(simulator)
        #expect(!context.defaultLibrarySupportsProgrammableBlending)
        #else
        #expect(context.defaultLibrarySupportsProgrammableBlending)
        #endif
    }
}

@Suite(.enabled(if: metalDeviceIsAvailable))
struct ContextOptionsTests {
    @Test func contextTexturePoolFactory() throws {
        do {
            var options = MTIContextOptions()
            options.makeTexturePool = { MTIDeviceTexturePool(device: $0) }
            let context = try makeContext(options: options)
            #expect(context.texturePool is MTIDeviceTexturePool)
        }
        do {
            if #available(iOS 13.0, macOS 10.15, *) {
                if let device = MTLCreateSystemDefaultDevice(), MTIHeapTexturePool.isSupported(on: device) {
                    var options = MTIContextOptions()
                    options.makeTexturePool = { MTIHeapTexturePool(device: $0) }
                    let context = try makeContext(options: options)
                    #expect(context.texturePool is MTIHeapTexturePool)
                }
            }
        }
    }

    @Test func coreVideoMetalTextureBridgeClass() throws {
        do {
            var options = MTIContextOptions()
            options.makeCoreVideoMetalTextureBridge = { try MTICVMetalTextureCache(device: $0) }
            let context = try makeContext(options: options)
            #expect(context.coreVideoTextureBridge is MTICVMetalTextureCache)
        }
        do {
            var options = MTIContextOptions()
            options.makeCoreVideoMetalTextureBridge = { MTICVMetalIOSurfaceBridge(device: $0) }
            let context = try makeContext(options: options)
            #expect(context.coreVideoTextureBridge is MTICVMetalIOSurfaceBridge)
        }
    }

    @Test func testWorkingPixelFormat() throws {
        do {
            let options = MTIContextOptions()
            let context = try makeContext(options: options)
            #expect(context.workingPixelFormat == .bgra8Unorm)
        }
        do {
            var options = MTIContextOptions()
            options.workingPixelFormat = .r16Float
            let context = try makeContext(options: options)
            #expect(context.workingPixelFormat == .r16Float)
        }
    }

    @Test func contextLabel() throws {
        do {
            let options = MTIContextOptions()
            let context = try makeContext(options: options)
            #expect(context.label == MTIContextDefaultLabel)
        }
        do {
            var options = MTIContextOptions()
            options.label = "test"
            let context = try makeContext(options: options)
            #expect(context.label == "test")
        }
    }

    @Test func testCoreImageContextOptions() throws {
        do {
            var options = MTIContextOptions()
            options.coreImageContextOptions = [CIContextOption.workingFormat: CIFormat.RGBA8]
            let context = try makeContext(options: options)
            #expect(context.coreImageContext.workingFormat == .RGBA8)
        }
        do {
            var options = MTIContextOptions()
            let colorspace = CGColorSpaceCreateDeviceRGB()
            options.coreImageContextOptions = [CIContextOption.workingColorSpace: colorspace]
            let context = try makeContext(options: options)
            #expect(context.coreImageContext.workingColorSpace == colorspace)
        }
    }
}
