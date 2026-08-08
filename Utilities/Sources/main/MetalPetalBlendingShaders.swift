import Foundation

private let blendModes = [
    "Normal",
    "Darken",
    "Multiply",
    "ColorBurn",
    "LinearBurn",
    "DarkerColor",
    "Lighten",
    "Screen",
    "ColorDodge",
    "Add",
    "LighterColor",
    "Overlay",
    "SoftLight",
    "HardLight",
    "VividLight",
    "LinearLight",
    "PinLight",
    "HardMix",
    "Difference",
    "Exclusion",
    "Subtract",
    "Divide",
    "Hue",
    "Saturation",
    "Color",
    "Luminosity",
]

private extension String {
    var lowerCamelCased: String {
        prefix(1).lowercased() + dropFirst()
    }

    func indented(by spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : prefix + $0 }
            .joined(separator: "\n")
    }
}

private func textureCoordinatesModifier(backdrop: String, sourceTexture: String) -> String {
    """
    #if MTI_CUSTOM_BLEND_HAS_TEXTURE_COORDINATES_MODIFIER
    textureCoordinate = modify_source_texture_coordinates(\(backdrop),
                                                          vertexIn.textureCoordinate,
                                                          uint2(\(sourceTexture).get_width(),
                                                          \(sourceTexture).get_height()));
    #endif
    """
}

private func multilayerCompositeLayerBody(
    backdrop: String,
    locationIsInScope: Bool,
    blendFunctionName: String
) -> String {
    let locationDeclaration = locationIsInScope
        ? ""
        : "\n    float2 location = vertexIn.position.xy / parameters.canvasSize;"
    return """
    float2 textureCoordinate = vertexIn.textureCoordinate;
    \(textureCoordinatesModifier(backdrop: backdrop, sourceTexture: "colorTexture"))
    float4 textureColor = colorTexture.sample(colorSampler, textureCoordinate);
    if (multilayer_composite_content_premultiplied) {
        textureColor = unpremultiply(textureColor);
    }
    if (multilayer_composite_has_mask) {
        float4 maskColor = maskTexture.sample(maskSampler, vertexIn.positionInLayer);
        maskColor = parameters.maskHasPremultipliedAlpha ? unpremultiply(maskColor) : maskColor;
        float maskValue = maskColor[parameters.maskComponent];
        textureColor.a *= parameters.maskUsesOneMinusValue ? (1.0 - maskValue) : maskValue;
    }
    if (multilayer_composite_has_compositing_mask) {\(locationDeclaration)
        float4 maskColor = compositingMaskTexture.sample(compositingMaskSampler, location);
        maskColor = parameters.compositingMaskHasPremultipliedAlpha ? unpremultiply(maskColor) : maskColor;
        float maskValue = maskColor[parameters.compositingMaskComponent];
        textureColor.a *= parameters.compositingMaskUsesOneMinusValue ? (1.0 - maskValue) : maskValue;
    }
    if (multilayer_composite_has_tint_color) {
        textureColor.rgb = parameters.tintColor.rgb;
        textureColor.a *= parameters.tintColor.a;
    }
    switch (multilayer_composite_corner_curve_type) {
        case 1:
            textureColor.a *= circularCornerMask(parameters.layerSize,
                                                 vertexIn.positionInLayer,
                                                 parameters.cornerRadius);
            break;
        case 2:
            textureColor.a *= continuousCornerMask(parameters.layerSize,
                                                   vertexIn.positionInLayer,
                                                   parameters.cornerRadius);
            break;
        default:
            break;
    }
    textureColor.a *= parameters.opacity;
    return \(blendFunctionName)(\(backdrop),textureColor);
    """
}

func generateMultilayerCompositeFilterFragmentShader(
    shaderFunctionName: String,
    blendFunctionName: String
) -> String {
    let programmableBlendingBody = multilayerCompositeLayerBody(
        backdrop: "currentColor",
        locationIsInScope: false,
        blendFunctionName: blendFunctionName
    ).indented(by: 4)
    let body = multilayerCompositeLayerBody(
        backdrop: "backgroundColor",
        locationIsInScope: true,
        blendFunctionName: blendFunctionName
    ).indented(by: 4)
    return """

    #if __HAVE_COLOR_ARGUMENTS__ && !TARGET_OS_SIMULATOR

    fragment float4 \(shaderFunctionName)_programmableBlending(
                MTIMultilayerCompositingLayerVertexOut vertexIn [[ stage_in ]],
                float4 currentColor [[color(0)]],
                constant MTIMultilayerCompositingLayerShadingParameters & parameters [[buffer(0)]],
                texture2d<float, access::sample> colorTexture [[ texture(0) ]],
                sampler colorSampler [[ sampler(0) ]],
                texture2d<float, access::sample> compositingMaskTexture [[ texture(1) ]],
                sampler compositingMaskSampler [[ sampler(1) ]],
                texture2d<float, access::sample> maskTexture [[ texture(2) ]],
                sampler maskSampler [[ sampler(2) ]]
            ) {
    \(programmableBlendingBody)
    }

    #endif

    fragment float4 \(shaderFunctionName)(
                MTIMultilayerCompositingLayerVertexOut vertexIn [[ stage_in ]],
                texture2d<float, access::sample> backgroundTexture [[ texture(1) ]],
                texture2d<float, access::sample> compositingMaskTexture [[ texture(2) ]],
                sampler compositingMaskSampler [[ sampler(2) ]],
                texture2d<float, access::sample> maskTexture [[ texture(3) ]],
                sampler maskSampler [[ sampler(3) ]],
                constant MTIMultilayerCompositingLayerShadingParameters & parameters [[buffer(0)]],
                texture2d<float, access::sample> colorTexture [[ texture(0) ]],
                sampler colorSampler [[ sampler(0) ]]
            ) {
        constexpr sampler s(coord::normalized, address::clamp_to_zero, filter::linear);
        float2 location = vertexIn.position.xy / parameters.canvasSize;
        float4 backgroundColor = backgroundTexture.sample(s, location);
    \(body)
    }


    """
}

func generateBlendFilterFragmentShader(shaderFunctionName: String,
                                       blendFunctionName: String) -> String
{
    """

    fragment float4 \(shaderFunctionName)(VertexOut vertexIn [[ stage_in ]],
                                        texture2d<float, access::sample> colorTexture [[ texture(0) ]],
                                        sampler colorSampler [[ sampler(0) ]],
                                        texture2d<float, access::sample> overlayTexture [[ texture(1) ]],
                                        sampler overlaySampler [[ sampler(1) ]],
                                        constant float &intensity [[buffer(0)]]
                                        ) {
        float4 uCb = colorTexture.sample(colorSampler, vertexIn.textureCoordinate);
        float2 textureCoordinate = vertexIn.textureCoordinate;
    \(textureCoordinatesModifier(backdrop: "uCb", sourceTexture: "overlayTexture").indented(by: 4))
        float4 uCf = overlayTexture.sample(overlaySampler, textureCoordinate);
        if (blend_filter_backdrop_has_premultiplied_alpha) {
            uCb = unpremultiply(uCb);
        }
        if (blend_filter_source_has_premultiplied_alpha) {
            uCf = unpremultiply(uCf);
        }
        float4 blendedColor = \(blendFunctionName)(uCb, uCf);
        float4 output = mix(uCb,blendedColor,intensity);
        if (blend_filter_outputs_premultiplied_alpha) {
            return premultiply(output);
        } else if (blend_filter_outputs_opaque_image) {
            return float4(output.rgb, 1.0);
        } else {
            return output;
        }
    }


    """
}

func generateBlendingShaders() -> String {
    let functions = blendModes.map { mode in
        let blendFunctionName = mode.lowerCamelCased + "Blend"
        return generateBlendFilterFragmentShader(
            shaderFunctionName: blendFunctionName,
            blendFunctionName: blendFunctionName
        )
    }.joined()
    return """
    \(autoGeneratedFileHeader)

    #include <metal_stdlib>
    #include "MTIShaderLib.h"
    #include "MTIShaderFunctionConstants.h"

    using namespace metal;
    using namespace metalpetal;

    namespace metalpetal {

    \(functions)

    }

    """
}

func generateMultilayerCompositeShaders() -> String {
    let functions = blendModes.map { mode in
        generateMultilayerCompositeFilterFragmentShader(
            shaderFunctionName: "multilayerComposite" + mode + "Blend",
            blendFunctionName: mode.lowerCamelCased + "Blend"
        )
    }.joined()
    return """
    \(autoGeneratedFileHeader)

    #include <metal_stdlib>
    #include <TargetConditionals.h>
    #include "MTIShaderLib.h"
    #include "MTIShaderFunctionConstants.h"

    #ifndef TARGET_OS_SIMULATOR
        #error TARGET_OS_SIMULATOR not defined. Check <TargetConditionals.h>
    #endif

    using namespace metal;
    using namespace metalpetal;

    namespace metalpetal {

    vertex MTIMultilayerCompositingLayerVertexOut multilayerCompositeVertexShader(
            const device MTIMultilayerCompositingLayerVertex * vertices [[ buffer(0) ]],
            constant float4x4 & transformMatrix [[ buffer(1) ]],
            constant float4x4 & orthographicMatrix [[ buffer(2) ]],
            uint vid [[ vertex_id ]]
            ) {
        MTIMultilayerCompositingLayerVertexOut outVertex;
        MTIMultilayerCompositingLayerVertex inVertex = vertices[vid];
        outVertex.position = inVertex.position * transformMatrix * orthographicMatrix;
        outVertex.textureCoordinate = inVertex.textureCoordinate;
        outVertex.positionInLayer = inVertex.positionInLayer;
        return outVertex;
    }

    \(functions)

    }

    """
}
