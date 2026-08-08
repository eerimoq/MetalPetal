//
//  MultilayerCompositingFilterView.swift
//  MetalPetalDemo
//
//  Created by YuAo on 2021/4/6.
//

import Foundation
import MetalPetal
import SwiftUI

struct MultilayerCompositingFilterView: View {
    static let grayScaleBlendMode: MTIBlendMode = {
        let mode = MTIBlendMode(String(#fileID) + String("\(#line)"))
        MTIBlendModes.registerBlendMode(mode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float4 blend(float4 backdrop, float4 source) {
            return float4(
                mix(backdrop.rgb, dot(backdrop.rgb, float3(0.299, 0.587, 0.114)), source.a),
                backdrop.a
            );
        }
        """))
        return mode
    }()

    // Index of the layers that are updated by the filter parameters below.
    private static let sparklesLayerIndex = 4
    private static let colorLookupLayerIndex = 5
    private static let grayScaleLayerIndex = 6

    private static let sparklesImage = DemoImages.makeSymbolImage(
        named: "sparkles",
        aspectFitIn: CGSize(width: 120, height: 120)
    )

    private static let dropImage = DemoImages.makeSymbolImage(
        named: "drop.fill",
        aspectFitIn: CGSize(width: 180, height: 180)
    )

    private static let colorLookupCompositingMask = MTIMask(
        content: DemoImages.makeSymbolImage(named: "diamond.fill", aspectFitIn: CGSize(
            width: 1080,
            height: 1920
        ), padding: 96),
        component: .alpha,
        mode: .normal
    )

    private static func makeTintedSymbolLayer(named name: String, column: Int, color: MTIColor) -> MTILayer {
        MTILayer(
            content: DemoImages.makeSymbolImage(named: name, aspectFitIn: CGSize(width: 120, height: 120)),
            position: CGPoint(x: 16 + (120 + 16) * CGFloat(column) + 60, y: 16 + 60),
            size: CGSize(width: 120, height: 120),
            tintColor: color
        )
    }

    private static func makeSparklesLayer(rotation: Float) -> MTILayer {
        MTILayer(
            content: sparklesImage,
            position: CGPoint(x: 56 + 60, y: 1080 - 16 - 60),
            size: CGSize(width: 120, height: 120),
            rotation: rotation,
            tintColor: MTIColor(red: 210 / 255.0, green: 180 / 255.0, blue: 40 / 255.0, alpha: 1),
            blendMode: .hardLight
        )
    }

    private static func makeColorLookupLayer(opacity: Float) -> MTILayer {
        MTILayer(
            content: DemoImages.colorLookupTable,
            compositingMask: colorLookupCompositingMask,
            layoutUnit: .fractionOfBackgroundSize,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 1, height: 1),
            opacity: opacity,
            blendMode: .colorLookup512x512
        )
    }

    private static func makeGrayScaleLayer(opacity: Float) -> MTILayer {
        MTILayer(
            content: dropImage,
            layoutUnit: .fractionOfBackgroundSize,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.18, height: 0.32),
            opacity: opacity,
            blendMode: MultilayerCompositingFilterView.grayScaleBlendMode
        )
    }

    var body: some View {
        ImageFilterView(filter: { () -> MTIMultilayerCompositingFilter in
            let filter = MTIMultilayerCompositingFilter()
            filter.layers = [
                // layers with tint color
                Self.makeTintedSymbolLayer(
                    named: "triangle.circle",
                    column: 0,
                    color: MTIColor(red: 54 / 255.0, green: 207 / 255.0, blue: 150 / 255.0, alpha: 1)
                ),
                Self.makeTintedSymbolLayer(
                    named: "circle.circle",
                    column: 1,
                    color: MTIColor(red: 213 / 255.0, green: 50 / 255.0, blue: 50 / 255.0, alpha: 1)
                ),
                Self.makeTintedSymbolLayer(
                    named: "xmark.circle",
                    column: 2,
                    color: MTIColor(red: 105 / 255.0, green: 133 / 255.0, blue: 197 / 255.0, alpha: 1)
                ),
                Self.makeTintedSymbolLayer(
                    named: "square.circle",
                    column: 3,
                    color: MTIColor(red: 212 / 255.0, green: 104 / 255.0, blue: 190 / 255.0, alpha: 1)
                ),
                // layer with blend mode
                Self.makeSparklesLayer(rotation: 0),
                // layer with compositing mask and color lookup blend mode
                Self.makeColorLookupLayer(opacity: 1),
                // layer with custom blend mode
                Self.makeGrayScaleLayer(opacity: 1),
                // layer with content region and mask
                MTILayer(
                    content: DemoImages.p1DepthMask,
                    contentRegion: MTIMakeRect(
                        aspectRatio: CGSize(width: 1, height: 1),
                        insideRect: DemoImages.p1DepthMask.extent
                    ),
                    mask: MTIMask(
                        content: DemoImages.makeSymbolImage(named: "hexagon.fill", aspectFitIn: CGSize(
                            width: 240,
                            height: 240
                        )),
                        component: .alpha,
                        mode: .normal
                    ),
                    position: CGPoint(x: 1920 - 16 - 120, y: 16 + 120),
                    size: CGSize(width: 240, height: 240)
                ),
                // bottom right layers
                MTILayer(
                    content: DemoImages.makeSymbolImage(
                        named: "capsule.fill",
                        aspectFitIn: CGSize(width: 180, height: 120)
                    ),
                    position: CGPoint(x: 1920 - 16 - 90, y: 1080 - 16 - 60),
                    size: CGSize(width: 180, height: 120),
                    tintColor: .white
                ),
                MTILayer(
                    content: DemoImages.makeSymbolImage(
                        named: "leaf.fill",
                        aspectFitIn: CGSize(width: 180, height: 120),
                        padding: 32
                    ),
                    position: CGPoint(x: 1920 - 16 - 90, y: 1080 - 16 - 60),
                    size: CGSize(width: 180, height: 120),
                    tintColor: MTIColor(red: 0.1, green: 0.9, blue: 0.1, alpha: 0.5)
                ),
            ]
            return filter
        }(),
        filterInputKeyPath: \.inputBackgroundImage,
        parameters: [
            FilterParameter(
                name: "Sparkles Rotation",
                defaultValue: 0,
                sliderRange: 0 ... (.pi * 2),
                updater: { filter, rotation in
                    filter.layers[Self.sparklesLayerIndex] = Self.makeSparklesLayer(rotation: rotation)
                }
            ),
            FilterParameter(
                name: "Color Lookup Intensity",
                defaultValue: 1,
                sliderRange: 0 ... 1,
                updater: { filter, intensity in
                    filter.layers[Self.colorLookupLayerIndex] = Self
                        .makeColorLookupLayer(opacity: intensity)
                }
            ),
            FilterParameter(
                name: "Gray Scale Blend Intensity",
                defaultValue: 1,
                sliderRange: 0 ... 1,
                updater: { filter, intensity in
                    filter.layers[Self.grayScaleLayerIndex] = Self.makeGrayScaleLayer(opacity: intensity)
                }
            ),
        ],
        isChangingImageAllowed: false)
            .inlineNavigationBarTitle("Multilayer Compositing")
    }
}
