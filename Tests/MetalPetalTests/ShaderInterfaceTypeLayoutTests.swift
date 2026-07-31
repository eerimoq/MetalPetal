//
//  ShaderInterfaceTypeLayoutTests.swift
//  MetalPetal
//
//  Locks the Swift shader-interface structs to the C ABI of their counterparts in
//  `Sources/MetalPetal/Shaders/MTIShaderLib.h`.
//
//  These structs are passed to the shaders by value via `setBytes`, and the C header is only ever compiled
//  by the Metal compiler at runtime -- so a mismatch between the two definitions produces no build error,
//  just silently wrong pixels or out-of-bounds reads on the GPU. The expected values below were obtained by
//  compiling MTIShaderLib.h with clang for arm64 and printing `sizeof`/`offsetof`; update them only
//  alongside a matching change to the C header.
//
//  Note that `setBytes` must be given `MemoryLayout<T>.stride`, not `.size`: Swift's `.size` excludes
//  trailing padding, so for `MTIMultilayerCompositingLayerShadingParameters` it reports 72 where C's
//  `sizeof` is 80.
//

@testable import MetalPetal
import simd
import Testing

@Suite("Shader interface type layout")
struct ShaderInterfaceTypeLayoutTests {
    @Test func multilayerCompositingLayerShadingParametersLayout() {
        typealias T = MTIMultilayerCompositingLayerShadingParameters
        #expect(MemoryLayout<T>.stride == 80)
        #expect(MemoryLayout<T>.alignment == 16)
        #expect(MemoryLayout<T>.offset(of: \.canvasSize) == 0)
        #expect(MemoryLayout<T>.offset(of: \.opacity) == 8)
        #expect(MemoryLayout<T>.offset(of: \.maskComponent) == 12)
        #expect(MemoryLayout<T>.offset(of: \.maskHasPremultipliedAlpha) == 16)
        #expect(MemoryLayout<T>.offset(of: \.maskUsesOneMinusValue) == 17)
        #expect(MemoryLayout<T>.offset(of: \.compositingMaskComponent) == 20)
        #expect(MemoryLayout<T>.offset(of: \.compositingMaskHasPremultipliedAlpha) == 24)
        #expect(MemoryLayout<T>.offset(of: \.compositingMaskUsesOneMinusValue) == 25)
        #expect(MemoryLayout<T>.offset(of: \.tintColor) == 32)
        #expect(MemoryLayout<T>.offset(of: \.cornerRadius) == 48)
        #expect(MemoryLayout<T>.offset(of: \.layerSize) == 64)
    }

    @Test func multilayerCompositingLayerVertexLayout() {
        typealias T = MTIMultilayerCompositingLayerVertex
        #expect(MemoryLayout<T>.stride == 32)
        #expect(MemoryLayout<T>.alignment == 16)
        #expect(MemoryLayout<T>.offset(of: \.position) == 0)
        #expect(MemoryLayout<T>.offset(of: \.textureCoordinate) == 16)
        #expect(MemoryLayout<T>.offset(of: \.positionInLayer) == 24)
    }

    @Test func claheLUTGeneratorInputParametersLayout() {
        typealias T = MTICLAHELUTGeneratorInputParameters
        #expect(MemoryLayout<T>.stride == 16)
        #expect(MemoryLayout<T>.offset(of: \.histogramBins) == 0)
        #expect(MemoryLayout<T>.offset(of: \.clipLimit) == 4)
        #expect(MemoryLayout<T>.offset(of: \.totalPixelCountPerTile) == 8)
        #expect(MemoryLayout<T>.offset(of: \.numberOfLUTs) == 12)
    }

    @Test func vertexLayout() {
        typealias T = MTIVertex
        #expect(MemoryLayout<T>.stride == 32)
        #expect(MemoryLayout<T>.alignment == 16)
        #expect(MemoryLayout<T>.offset(of: \.position) == 0)
        #expect(MemoryLayout<T>.offset(of: \.textureCoordinate) == 16)
    }
}
