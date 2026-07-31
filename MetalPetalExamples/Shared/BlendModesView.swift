//
//  BlendModesView.swift
//  MetalPetalDemo
//
//  Created by YuAo on 2021/4/3.
//

import Foundation
import MetalPetal
import SwiftUI

struct BlendModesView: View {
    @State private var inputImage: MTIImage = DemoImages.p1040808
    @State private var inputOverlayImage: MTIImage = RGUVGradientImage.makeImage(size: CGSize(
        width: 1280,
        height: 720
    ))
    @State private var blendMode: MTIBlendMode = .normal
    @State private var intensity: Float = 0.75
    @StateObject private var renderContext = try! MTIContext(device: MTLCreateSystemDefaultDevice()!)

    private func filter(_: MTIImage) throws -> CGImage {
        let blendFilter = MTIBlendFilter(blendMode: blendMode)
        blendFilter.inputBackgroundImage = inputImage
        blendFilter.inputImage = inputOverlayImage
        blendFilter.intensity = intensity
        let filteredImage = blendFilter.outputImage!
        return try renderContext.makeCGImage(from: filteredImage)
    }

    var body: some View {
        Group {
            switch Result(catching: { try filter(inputImage) }) {
            case let .success(image):
                VStack {
                    Image(cgImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    VStack(alignment: .leading) {
                        Picker(blendModePickerLabel, selection: $blendMode, content: {
                            ForEach(MTIBlendModes.all) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        })
                        .blendModesPickerStyle()
                        VStack(alignment: .leading) {
                            Text("Intensity \(intensity, specifier: "%.2f")")
                            Slider(value: $intensity, in: 0 ... 1)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10)
                            .foregroundColor(Color.secondarySystemBackground))
                    }
                    .padding()
                }
            case let .failure(error):
                Text(error.localizedDescription)
            }
        }
        .toolbarMenu(Menu(content: {
            ImagePicker(title: "Background Image", handler: { url in
                if let image = ImageUtilities.loadUserPickedImage(
                    from: url,
                    requiresUnpremultipliedAlpha: false
                ) {
                    inputImage = image
                }
            })
            ImagePicker(title: "Foreground Image", handler: { url in
                if let image = ImageUtilities.loadUserPickedImage(
                    from: url,
                    requiresUnpremultipliedAlpha: false
                ) {
                    inputOverlayImage = image
                }
            })
        }, label: {
            Text("Choose Image").fontWeight(.regular)
        }))
        .inlineNavigationBarTitle("Blend Modes")
    }

    private var blendModePickerLabel: String {
        #if os(iOS)
        return blendMode.rawValue
        #else
        return "Blend Mode"
        #endif
    }
}

private extension Picker {
    func blendModesPickerStyle() -> some View {
        pickerStyle(WheelPickerStyle())
            .background(RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color.secondarySystemBackground))
    }
}

extension MTIBlendMode: @retroactive Identifiable {
    public var id: String {
        rawValue
    }
}
