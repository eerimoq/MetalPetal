//
//  KernelConfigurationTests.swift
//  MetalPetal
//
//  MTIContext caches one kernel state per distinct `MTIKernelConfiguration.identifier`. If equal
//  configurations stopped producing equal identifiers the cache would simply always miss -- pipelines
//  would be rebuilt on every render with correct output and no test failure, only a silent performance
//  cliff. These tests pin the equality and hashing the cache relies on.
//

import Metal
@testable import MetalPetal
import Testing

@Suite("Kernel configuration cache keys")
struct KernelConfigurationTests {
    private func configuration(
        pixelFormat: MTLPixelFormat = .bgra8Unorm,
        rasterSampleCount: Int = 1
    ) -> MTIRenderPipelineKernelConfiguration {
        MTIRenderPipelineKernelConfiguration(
            colorAttachmentPixelFormats: [pixelFormat],
            depthAttachmentPixelFormat: .invalid,
            stencilAttachmentPixelFormat: .invalid,
            rasterSampleCount: rasterSampleCount
        )
    }

    @Test func equalConfigurationsShareACacheKey() {
        let a = configuration()
        let b = configuration()
        #expect(a !== b)
        #expect(a.identifier == b.identifier)
        #expect(a.identifier.hashValue == b.identifier.hashValue)
        var store: [AnyHashable: Int] = [:]
        store[a.identifier] = 1
        store[b.identifier] = 2
        #expect(store.count == 1)
        #expect(store[a.identifier] == 2)
    }

    @Test func differingConfigurationsDoNotShareACacheKey() {
        let base = configuration()
        let differentFormat = configuration(pixelFormat: .rgba16Float)
        let differentSampleCount = configuration(rasterSampleCount: 4)
        #expect(base.identifier != differentFormat.identifier)
        #expect(base.identifier != differentSampleCount.identifier)
        var store: [AnyHashable: Int] = [:]
        store[base.identifier] = 1
        store[differentFormat.identifier] = 2
        store[differentSampleCount.identifier] = 3
        #expect(store.count == 3)
    }
}
