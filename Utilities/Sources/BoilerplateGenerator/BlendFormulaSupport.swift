//
//  BlendFormulaSupport.swift
//
//  Created by YuAo on 2021/2/6.
//

import Foundation

enum BlendFormulaSupport {
    static func generateBlendFormulaSupportFiles(sourceDirectory: URL) throws -> [String: String] {
        let sourceHeaderFile = sourceDirectory.appending(path: "Shaders/MTIShaderLib.h")
        let shaderHeaderContent = try String(contentsOf: sourceHeaderFile, encoding: .utf8)
        let functionConstantsHeaderFile = sourceDirectory
            .appending(path: "Shaders/MTIShaderFunctionConstants.h")
        let functionConstantsContent = try String(contentsOf: functionConstantsHeaderFile, encoding: .utf8)
        let imp = ##"""
        //
        // This is an auto-generated source file.
        //

        import Foundation

        private let shaderTemplate = #"""
        \##(shaderHeaderContent)
        \##(functionConstantsContent)

        using namespace metalpetal;

        {MTIBlendFormula}

        \##(MetalPetalBlendingShadersCodeGenerator.generateBlendFilterFragmentShader(
            shaderFunctionName: "customBlend",
            blendFunctionName: "blend"
        ))

        \##(MetalPetalBlendingShadersCodeGenerator.generateMultilayerCompositeFilterFragmentShader(
            shaderFunctionName: "multilayerCompositeCustomBlend",
            blendFunctionName: "blend"
        ))

        """#

        func MTIBuildBlendFormulaShaderSource(_ formula: String) -> String {
            #if targetEnvironment(simulator)
            let targetOSSimulator = 1
            #else
            let targetOSSimulator = 0
            #endif
            let hasTextureCoordinatesModifier = formula.contains("modify_source_texture_coordinates") ? 1 : 0
            let targetConditionals = """
                #ifndef TARGET_OS_SIMULATOR
                #define TARGET_OS_SIMULATOR \(targetOSSimulator)
                #endif\n\n#define MTI_CUSTOM_BLEND_HAS_TEXTURE_COORDINATES_MODIFIER \(hasTextureCoordinatesModifier)

                """
            return shaderTemplate
                .replacingOccurrences(of: "{MTIBlendFormula}", with: targetConditionals + formula)
        }

        """##

        return [
            "MTIBlendFormulaSupport.swift": imp,
        ]
    }
}
