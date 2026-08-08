//
//  MTIBlendModes.swift
//  MetalPetal
//
//  Created by Yu Ao on 30/09/2017.
//

import Foundation
import Metal
import os

/// Modes that describe how source colors blend with destination colors.
/// See also: https://www.w3.org/TR/compositing-1/
public struct MTIBlendMode: RawRepresentable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let normal = MTIBlendMode("Normal")

    public static let darken = MTIBlendMode("Darken")
    public static let multiply = MTIBlendMode("Multiply")
    public static let colorBurn = MTIBlendMode("ColorBurn")
    public static let linearBurn = MTIBlendMode("LinearBurn")
    public static let darkerColor = MTIBlendMode("DarkerColor")

    public static let lighten = MTIBlendMode("Lighten")
    public static let screen = MTIBlendMode("Screen")
    public static let colorDodge = MTIBlendMode("ColorDodge")
    public static let add = MTIBlendMode("Add") // also LinearDodge
    public static let lighterColor = MTIBlendMode("LighterColor")

    public static let overlay = MTIBlendMode("Overlay")
    public static let softLight = MTIBlendMode("SoftLight")
    public static let hardLight = MTIBlendMode("HardLight")
    public static let vividLight = MTIBlendMode("VividLight")
    public static let linearLight = MTIBlendMode("LinearLight")
    public static let pinLight = MTIBlendMode("PinLight")
    public static let hardMix = MTIBlendMode("HardMix")

    public static let difference = MTIBlendMode("Difference")
    public static let exclusion = MTIBlendMode("Exclusion")
    public static let subtract = MTIBlendMode("Subtract")
    public static let divide = MTIBlendMode("Divide")

    public static let hue = MTIBlendMode("Hue")
    public static let saturation = MTIBlendMode("Saturation")
    public static let color = MTIBlendMode("Color")
    public static let luminosity = MTIBlendMode("Luminosity")

    public static let colorLookup512x512 = MTIBlendMode("ColorLookup512x512")
}

public struct MTIBlendFunctionDescriptors {
    public let forBlendFilter: MTIFunctionDescriptor
    public let forMultilayerCompositingFilterWithProgrammableBlending: MTIFunctionDescriptor?
    public let forMultilayerCompositingFilterWithoutProgrammableBlending: MTIFunctionDescriptor?

    public init(
        forBlendFilter: MTIFunctionDescriptor,
        forMultilayerCompositingFilterWithProgrammableBlending: MTIFunctionDescriptor?,
        forMultilayerCompositingFilterWithoutProgrammableBlending: MTIFunctionDescriptor?
    ) {
        self.forBlendFilter = forBlendFilter
        self.forMultilayerCompositingFilterWithProgrammableBlending =
            forMultilayerCompositingFilterWithProgrammableBlending
        self.forMultilayerCompositingFilterWithoutProgrammableBlending =
            forMultilayerCompositingFilterWithoutProgrammableBlending
    }

    /// Creates a `MTIBlendFunctionDescriptors` using a metal shader function.
    ///
    /// The name of the function must be `blend`. The function must have exactly two arguments of type
    /// `float4`. The first argument represents the value of the backdrop pixel and the second represents
    /// the source pixel. The value returned by the function will be the new destination color. All colors
    /// should have unpremultiplied alpha component.
    public init(blendFormula formula: String) {
        let compileOptions = MTLCompileOptions()
        let shaderLibraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: MTIBuildBlendFormulaShaderSource(formula),
            compileOptions: compileOptions
        )
        self.init(
            forBlendFilter: MTIFunctionDescriptor(
                name: "customBlend",
                libraryURL: shaderLibraryURL
            ),
            forMultilayerCompositingFilterWithProgrammableBlending: MTIFunctionDescriptor(
                name: "multilayerCompositeCustomBlend_programmableBlending",
                libraryURL: shaderLibraryURL
            ),
            forMultilayerCompositingFilterWithoutProgrammableBlending: MTIFunctionDescriptor(
                name: "multilayerCompositeCustomBlend",
                libraryURL: shaderLibraryURL
            )
        )
    }
}

public enum MTIBlendModes {
    private static let lock = OSAllocatedUnfairLock()
    private static var registeredBlendModes: [MTIBlendMode: MTIBlendFunctionDescriptors] = MTIBlendModes
        .makeBuiltinBlendModes()

    private static func makeBuiltinBlendModes() -> [MTIBlendMode: MTIBlendFunctionDescriptors] {
        let builtinModes: [MTIBlendMode] = [
            .normal,
            .darken,
            .multiply,
            .colorBurn,
            .linearBurn,
            .darkerColor,
            .lighten,
            .screen,
            .colorDodge,
            .add,
            .lighterColor,
            .overlay,
            .hardMix,
            .softLight,
            .hardLight,
            .linearLight,
            .vividLight,
            .pinLight,
            .difference,
            .exclusion,
            .subtract,
            .divide,
            .hue,
            .color,
            .saturation,
            .luminosity,
            .colorLookup512x512,
        ]
        var modes: [MTIBlendMode: MTIBlendFunctionDescriptors] = [:]
        for mode in builtinModes {
            let raw = mode.rawValue
            let fragmentFunctionNameForBlendFilter = lowercasingFirstLetter(raw) + "Blend"
            let fragmentFunctionNameForMultilayerWithoutPB = "multilayerComposite\(raw)Blend"
            let fragmentFunctionNameForMultilayerWithPB = "multilayerComposite\(raw)Blend_programmableBlending"
            modes[mode] = MTIBlendFunctionDescriptors(
                forBlendFilter: MTIFunctionDescriptor(
                    name: fragmentFunctionNameForBlendFilter
                ),
                forMultilayerCompositingFilterWithProgrammableBlending: MTIFunctionDescriptor(
                    name: fragmentFunctionNameForMultilayerWithPB
                ),
                forMultilayerCompositingFilterWithoutProgrammableBlending: MTIFunctionDescriptor(
                    name: fragmentFunctionNameForMultilayerWithoutPB
                )
            )
        }
        return modes
    }

    private static func lowercasingFirstLetter(_ string: String) -> String {
        guard let first = string.first else {
            return string
        }
        return first.lowercased() + string.dropFirst()
    }

    public static var all: [MTIBlendMode] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return Array(registeredBlendModes.keys)
    }

    public static func registerBlendMode(
        _ blendMode: MTIBlendMode,
        with functionDescriptors: MTIBlendFunctionDescriptors
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }
        registeredBlendModes[blendMode] = functionDescriptors
    }

    public static func unregisterBlendMode(_ blendMode: MTIBlendMode) {
        lock.lock()
        defer {
            lock.unlock()
        }
        registeredBlendModes[blendMode] = nil
    }

    public static func functionDescriptors(for blendMode: MTIBlendMode) -> MTIBlendFunctionDescriptors? {
        lock.lock()
        defer {
            lock.unlock()
        }
        return registeredBlendModes[blendMode]
    }
}
