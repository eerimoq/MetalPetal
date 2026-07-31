//
//  MTIShaderInterfaceTypes.swift
//  MetalPetal
//
//  Swift definitions of the C structs shared with the Metal shaders (see Shaders/MTIShaderLib.h).
//  These are passed to shaders by value (setBytes), so their stored-property order and types MUST match
//  the corresponding C structs exactly. Only add simd/trivial fields, in the same order as the C header.
//

import simd

public struct MTICLAHELUTGeneratorInputParameters {
    public var histogramBins: UInt32 = 0
    public var clipLimit: UInt32 = 0
    public var totalPixelCountPerTile: UInt32 = 0
    public var numberOfLUTs: UInt32 = 0

    public init() {}
}

public struct MTIMultilayerCompositingLayerShadingParameters {
    public var canvasSize: simd_float2 = .init()
    public var opacity: Float = 0
    public var maskComponent: Int32 = 0
    public var maskHasPremultipliedAlpha: Bool = false
    public var maskUsesOneMinusValue: Bool = false
    public var compositingMaskComponent: Int32 = 0
    public var compositingMaskHasPremultipliedAlpha: Bool = false
    public var compositingMaskUsesOneMinusValue: Bool = false
    public var tintColor: simd_float4 = .init()
    public var cornerRadius: simd_float4 = .init()
    public var layerSize: simd_float2 = .init()

    public init() {}
}

public struct MTIMultilayerCompositingLayerVertex {
    public var position: simd_float4 = .init()
    public var textureCoordinate: simd_float2 = .init()
    public var positionInLayer: simd_float2 = .init()

    public init() {}

    public init(position: simd_float4, textureCoordinate: simd_float2, positionInLayer: simd_float2) {
        self.position = position
        self.textureCoordinate = textureCoordinate
        self.positionInLayer = positionInLayer
    }
}
