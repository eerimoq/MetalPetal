//
//  ContextTests.swift
//
//
//  Created by YuAo on 2021/2/2.
//

@testable import MetalPetal
import MetalPetalTestHelpers
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
}

@Suite(.enabled(if: metalDeviceIsAvailable))
struct ContextOptionsTests {
    @Test func contextTexturePoolFactory() throws {
        do {
            let options = MTIContextOptions()
            options.makeTexturePool = { MTIDeviceTexturePool(device: $0) }
            let context = try makeContext(options: options)
            #expect(context.texturePool is MTIDeviceTexturePool)
        }
        do {
            if #available(iOS 13.0, macOS 10.15, *) {
                if let device = MTLCreateSystemDefaultDevice(), MTIHeapTexturePool.isSupported(on: device) {
                    let options = MTIContextOptions()
                    options.makeTexturePool = { MTIHeapTexturePool(device: $0) }
                    let context = try makeContext(options: options)
                    #expect(context.texturePool is MTIHeapTexturePool)
                }
            }
        }
    }

    @Test func coreVideoMetalTextureBridgeClass() throws {
        do {
            let options = MTIContextOptions()
            options.makeCoreVideoMetalTextureBridge = { try MTICVMetalTextureCache(device: $0) }
            let context = try makeContext(options: options)
            #expect(context.coreVideoTextureBridge is MTICVMetalTextureCache)
        }
        do {
            let options = MTIContextOptions()
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
            let options = MTIContextOptions()
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
            let options = MTIContextOptions()
            options.label = "test"
            let context = try makeContext(options: options)
            #expect(context.label == "test")
        }
    }

    @Test func testCoreImageContextOptions() throws {
        do {
            let options = MTIContextOptions()
            options.coreImageContextOptions = [CIContextOption.workingFormat: CIFormat.RGBA8]
            let context = try makeContext(options: options)
            #expect(context.coreImageContext.workingFormat == .RGBA8)
        }
        do {
            let options = MTIContextOptions()
            let colorspace = CGColorSpaceCreateDeviceRGB()
            options.coreImageContextOptions = [CIContextOption.workingColorSpace: colorspace]
            let context = try makeContext(options: options)
            #expect(context.coreImageContext.workingColorSpace == colorspace)
        }
    }
}
