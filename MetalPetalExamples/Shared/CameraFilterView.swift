//
//  CameraFilterView.swift
//  MetalPetalDemo
//
//  Created by YuAo on 2021/4/3.
//

import AVKit
import Foundation
import MetalPetal
import os
import SwiftUI
import VideoIO
import VideoToolbox

class CapturePipeline: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    struct Effect: Identifiable {
        typealias Filter = (MTIImage) -> MTIImage

        let name: String
        let makeFilter: () -> Filter

        var id: String {
            name
        }

        init(_ name: String, makeFilter: @escaping () -> Filter) {
            self.name = name
            self.makeFilter = makeFilter
        }
    }

    @Published var previewImage: CGImage?
    private let renderContext = try! MTIContext(device: MTLCreateSystemDefaultDevice()!)
    private let queue: DispatchQueue = .init(label: "org.metalpetal.capture")

    private let camera: Camera = {
        var configurator = Camera.Configurator()
        #if os(iOS)
        let interfaceOrientation = UIApplication.shared.activeWindowScene?.interfaceOrientation
        #endif
        configurator.videoConnectionConfigurator = { _, connection in
            #if os(iOS)
            switch interfaceOrientation {
            case .landscapeLeft:
                connection.videoOrientation = .landscapeLeft
            case .landscapeRight:
                connection.videoOrientation = .landscapeRight
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            default:
                connection.videoOrientation = .portrait
            }
            #else
            connection.videoOrientation = .portrait
            #endif
        }
        return Camera(
            captureSessionPreset: .hd1920x1080,
            defaultCameraPosition: .front,
            configurator: configurator
        )
    }()

    private let imageRenderer = PixelBufferPoolBackedImageRenderer()
    private var filter: Effect.Filter = { $0 }

    @Published var effect: Effect = .noFilter {
        didSet {
            let filter = effect.makeFilter()
            queue.async {
                self.filter = filter
            }
        }
    }

    override init() {
        super.init()
        try? camera.enableVideoDataOutput(on: queue, delegate: self)
        camera.videoDataOutput?
            .videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
    }

    func startRunningCaptureSession() {
        queue.async {
            self.camera.startRunningCaptureSession()
        }
    }

    func stopRunningCaptureSession() {
        queue.async {
            self.camera.stopRunningCaptureSession()
        }
    }

    private static func croppedToCenterSquare(_ image: MTIImage) -> MTIImage {
        let side = min(image.size.width, image.size.height)
        let bounds = CGRect(
            x: (image.size.width - side) / 2,
            y: image.size.height - side,
            width: side,
            height: side * 0.75
        )
        return image.cropped(to: bounds) ?? image
    }

    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let formatDescription = sampleBuffer.formatDescription else {
            return
        }
        switch formatDescription.mediaType {
        case .video:
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            do {
                let image = CapturePipeline
                    .croppedToCenterSquare(MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .alphaIsOne))
                let filterOutputImage = filter(image)
                let renderOutput = try imageRenderer.render(filterOutputImage, using: renderContext)
                DispatchQueue.main.async {
                    self.previewImage = renderOutput.cgImage
                }
            } catch {
                print(error)
            }
        default:
            break
        }
    }
}

extension CapturePipeline.Effect: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension CapturePipeline.Effect {
    static let noFilter = Self("No Filter") {
        { $0 }
    }

    static let all: [Self] = basic + colorAdjustment + blurAndSharpen + stylize + geometry
        + compositing + analysis + coreImage

    private static func applying(_ makeFilter: @escaping () -> some MTIUnaryFilter) -> () -> Filter {
        {
            let filter = makeFilter()
            return { image in
                filter.inputImage = image
                return filter.outputImage!
            }
        }
    }

    private static func applying<F: MTIFilter>(
        _ makeFilter: @escaping () -> F,
        inputImage keyPath: ReferenceWritableKeyPath<F, MTIImage?>
    ) -> () -> Filter {
        {
            let filter = makeFilter()
            return { image in
                filter[keyPath: keyPath] = image
                return filter.outputImage!
            }
        }
    }

    private static func makeImageProvider(
        _ makeImage: @escaping (CGSize) -> MTIImage
    ) -> (CGSize) -> MTIImage {
        var cachedSize: CGSize?
        var cachedImage: MTIImage?
        return { size in
            if let cachedImage, cachedSize == size {
                return cachedImage
            }
            let image = makeImage(size).withCachePolicy(.persistent)
            cachedSize = size
            cachedImage = image
            return image
        }
    }

    private static func makeDemoImageProvider() -> (CGSize) -> MTIImage {
        makeImageProvider { size in
            DemoImages.p1040808.resized(to: size) ?? DemoImages.p1040808
        }
    }

    private static let basic: [Self] = [noFilter]

    private static let colorAdjustment: [Self] = [
        Self("Brightness", makeFilter: applying {
            let filter = MTIBrightnessFilter()
            filter.brightness = 0.2
            return filter
        }),
        Self("Contrast", makeFilter: applying {
            let filter = MTIContrastFilter()
            filter.contrast = 1.5
            return filter
        }),
        Self("Exposure", makeFilter: applying {
            let filter = MTIExposureFilter()
            filter.exposure = 1
            return filter
        }),
        Self("Saturation", makeFilter: applying {
            let filter = MTISaturationFilter()
            filter.saturation = 2
            return filter
        }),
        Self("Gray Scale", makeFilter: applying {
            let filter = MTISaturationFilter()
            filter.saturation = 0
            return filter
        }),
        Self("Vibrance", makeFilter: applying {
            let filter = MTIVibranceFilter()
            filter.amount = 1
            return filter
        }),
        Self("Opacity", makeFilter: applying {
            let filter = MTIOpacityFilter()
            filter.opacity = 0.5
            return filter
        }),
        Self("Color Invert", makeFilter: applying {
            MTIColorInvertFilter()
        }),
        Self("Color Matrix (Sepia)", makeFilter: applying {
            let filter = MTIColorMatrixFilter()
            filter.colorMatrix = MTIColorMatrix(
                matrix: simd_float4x4(columns: (
                    SIMD4<Float>(0.393, 0.769, 0.189, 0),
                    SIMD4<Float>(0.349, 0.686, 0.168, 0),
                    SIMD4<Float>(0.272, 0.534, 0.131, 0),
                    SIMD4<Float>(0, 0, 0, 1)
                )),
                bias: SIMD4<Float>(0, 0, 0, 0)
            )
            return filter
        }),
        Self("Color Grading (Color Lookup)", makeFilter: applying({
            let filter = MTIColorLookupFilter()
            filter.inputColorLookupTable = DemoImages.colorLookupTable
            return filter
        }, inputImage: \.inputImage)),
        Self("RGB Tone Curve", makeFilter: applying({
            let filter = MTIRGBToneCurveFilter()
            filter.rgbCompositeControlPoints = [
                MTIVector(value: CGPoint(x: 0, y: 0)),
                MTIVector(value: CGPoint(x: 0.5, y: 0.75)),
                MTIVector(value: CGPoint(x: 1, y: 1)),
            ]
            return filter
        }, inputImage: \.inputImage)),
        Self("CLAHE", makeFilter: applying {
            let filter = MTICLAHEFilter()
            filter.clipLimit = 2
            filter.tileGridSize = MTICLAHESize(width: 8, height: 8)
            return filter
        }),
        Self("RGB Color Space Conversion", makeFilter: applying {
            let filter = MTIRGBColorSpaceConversionFilter()
            filter.inputColorSpace = .linearSRGB
            filter.outputColorSpace = .sRGB
            filter.outputAlphaType = .alphaIsOne
            return filter
        }),
        Self("Linear RGB to sRGB Tone Curve", makeFilter: applying {
            MTILinearToSRGBToneCurveFilter()
        }),
        Self("sRGB Tone Curve to Linear RGB", makeFilter: applying {
            MTISRGBToneCurveToLinearFilter()
        }),
        Self("ITU-R 709 RGB to Linear RGB", makeFilter: applying {
            MTIITUR709RGBToLinearRGBFilter()
        }),
        Self("ITU-R 709 RGB to sRGB", makeFilter: applying {
            MTIITUR709RGBToSRGBFilter()
        }),
        // The camera frames are opaque, so the alpha filters below pass them through unchanged.
        Self("Premultiply Alpha", makeFilter: applying {
            MTIPremultiplyAlphaFilter()
        }),
        Self("Unpremultiply Alpha", makeFilter: applying {
            MTIUnpremultiplyAlphaFilter()
        }),
    ]

    private static let blurAndSharpen: [Self] = [
        Self("MPS Gaussian Blur", makeFilter: applying {
            let filter = MTIMPSGaussianBlurFilter()
            filter.radius = 10
            return filter
        }),
        Self("MPS Box Blur", makeFilter: applying {
            let filter = MTIMPSBoxBlurFilter()
            filter.size = simd_make_int2(15, 15)
            return filter
        }),
        Self("MPS Unsharp Mask", makeFilter: applying {
            let filter = MTIMPSUnsharpMaskFilter()
            filter.scale = 2
            filter.radius = 4
            return filter
        }),
        Self("MPS Definition", makeFilter: applying {
            let filter = MTIMPSDefinitionFilter()
            filter.intensity = 1
            return filter
        }),
        Self("MPS Sobel", makeFilter: applying {
            MTIMPSSobelFilter()
        }),
        Self("MPS Convolution (Emboss)", makeFilter: applying {
            let weights: [Float] = [-2, -1, 0,
                                    -1, 1, 1,
                                    0, 1, 2]
            return weights.withUnsafeBufferPointer { buffer in
                MTIMPSConvolutionFilter(kernelWidth: 3, kernelHeight: 3, weights: buffer.baseAddress!)
            }
        }),
        Self("Hexagonal Bokeh Blur") {
            let filter = MTIHexagonalBokehBlurFilter()
            filter.radius = 15
            filter.brightness = 0.5
            return { image in
                filter.inputImage = image.withSamplerDescriptor(
                    .defaultSamplerDescriptor(withAddressMode: .clampToEdge)
                )
                return filter.outputImage!
            }
        },
        Self("High Pass Skin Smoothing", makeFilter: applying({
            let filter = MTIHighPassSkinSmoothingFilter()
            filter.amount = 1
            filter.radius = 8
            return filter
        }, inputImage: \.inputImage)),
    ]

    private static let stylize: [Self] = {
        var effects: [Self] = [
            Self("Color Halftone", makeFilter: applying {
                let filter = MTIColorHalftoneFilter()
                filter.scale = 16
                return filter
            }),
            Self("Dot Screen", makeFilter: applying {
                let filter = MTIDotScreenFilter()
                filter.scale = 12
                return filter
            }),
            Self("Pixellate", makeFilter: applying {
                let filter = MTIPixellateFilter()
                filter.scale = CGSize(width: 16, height: 16)
                return filter
            }),
            Self("Bulge Distortion") {
                let filter = MTIBulgeDistortionFilter()
                filter.scale = 0.5
                return { image in
                    filter.center = simd_make_float2(
                        Float(image.size.width / 2),
                        Float(image.size.height / 2)
                    )
                    filter.radius = Float(min(image.size.width, image.size.height) / 2)
                    filter.inputImage = image
                    return filter.outputImage!
                }
            },
            Self("Round Corner") {
                let filter = MTIRoundCornerFilter()
                filter.cornerCurve = .continuous
                return { image in
                    filter.cornerRadius = MTICornerRadius(
                        Float(min(image.size.width, image.size.height) / 8)
                    )
                    filter.inputImage = image
                    return filter.outputImage!
                }
            },
        ]
        return effects
    }()

    private static let geometry: [Self] = [
        Self("Crop", makeFilter: applying {
            let filter = MTICropFilter()
            filter.cropRegion = .fractional(CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
            return filter
        }),
        Self("Transform", makeFilter: applying {
            let filter = MTITransformFilter()
            filter.transform = CATransform3DMakeRotation(.pi / 12, 0, 0, 1)
            return filter
        }),
    ]

    private static let compositing: [Self] = [
        Self("Blend (Multiply)") {
            let filter = MTIBlendFilter(blendMode: .multiply)
            let backgroundImage = makeDemoImageProvider()
            return { image in
                filter.inputBackgroundImage = backgroundImage(image.size)
                filter.inputImage = image
                return filter.outputImage!
            }
        },
        Self("Blend with Mask") {
            let filter = MTIBlendWithMaskFilter()
            let backgroundImage = makeDemoImageProvider()
            let maskImage = makeImageProvider { size in
                RadialGradientImage.makeImage(size: size)
            }
            return { image in
                filter.inputBackgroundImage = backgroundImage(image.size)
                filter.inputImage = image
                filter.inputMask = MTIMask(
                    content: maskImage(image.size),
                    component: .red,
                    mode: .normal
                )
                return filter.outputImage!
            }
        },
        Self("Chroma Key Blend") {
            let filter = MTIChromaKeyBlendFilter()
            filter.color = MTIColor(red: 0, green: 1, blue: 0, alpha: 1)
            filter.thresholdSensitivity = 0.4
            filter.smoothing = 0.1
            let backgroundImage = makeDemoImageProvider()
            return { image in
                filter.inputBackgroundImage = backgroundImage(image.size)
                filter.inputImage = image
                return filter.outputImage!
            }
        },
        Self("Multilayer Compositing") {
            let filter = MultilayerCompositingFilter()
            let overlayImage = makeImageProvider { size in
                DemoImages.makeSymbolImage(
                    named: "sparkles",
                    aspectFitIn: CGSize(width: size.width / 3, height: size.height / 3)
                )
            }
            return { image in
                let overlay = overlayImage(image.size)
                filter.inputBackgroundImage = image
                filter.layers = [
                    MultilayerCompositingFilter.Layer(content: overlay)
                        .tintColor(MTIColor(red: 210 / 255.0, green: 180 / 255.0, blue: 40 / 255.0, alpha: 1))
                        .frame(
                            center: CGPoint(x: image.size.width / 2, y: image.size.height / 2),
                            size: overlay.size,
                            layoutUnit: .pixel
                        )
                        .blendMode(.hardLight),
                ]
                return filter.outputImage!
            }
        },
    ]

    private static let analysis: [Self] = [
        Self("Histogram Display") {
            let histogramFilter = MTIMPSHistogramFilter()
            let displayFilter = MTIHistogramDisplayFilter()
            return { image in
                histogramFilter.inputImage = image
                displayFilter.outputSize = image.size
                displayFilter.inputImage = histogramFilter.outputImage
                return displayFilter.outputImage!
            }
        },
    ]

    private static let coreImage: [Self] = [
        Self("CIPhotoEffectInstant", makeFilter: applying({
            let filter = MTICoreImageUnaryFilter()
            filter.filter = CIFilter(name: "CIPhotoEffectInstant")
            return filter
        }, inputImage: \.inputImage)),
        Self("CIBloom") {
            { image in
                MTICoreImageKernel.image(byProcessing: [image], using: { inputs in
                    let extent = inputs[0].extent
                    return inputs[0].clampedToExtent().applyingFilter("CIBloom").cropped(to: extent)
                }, outputDimensions: image.dimensions)
            }
        },
    ]
}

struct CameraFilterView: View {
    @StateObject private var capturePipeline = CapturePipeline()

    var body: some View {
        VStack {
            Group {
                if let cgImage = capturePipeline.previewImage {
                    Image(cgImage: cgImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    cameraUnavailableView
                }
            }
            .frame(maxWidth: .infinity)
            Picker("", selection: $capturePipeline.effect) {
                ForEach(CapturePipeline.Effect.all) { effect in
                    Text(effect.name)
                        .tag(effect)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .padding([.horizontal])
            Spacer()
        }
        .onAppear {
            capturePipeline.startRunningCaptureSession()
        }
        .onDisappear {
            capturePipeline.stopRunningCaptureSession()
        }
        .inlineNavigationBarTitle("Camera")
    }

    private var cameraUnavailableView: some View {
        Rectangle()
            .foregroundColor(Color.gray.opacity(0.5))
            .aspectRatio(CGSize(width: 1, height: 0.75), contentMode: .fit)
            .overlay(Image(systemName: "video.fill")
                .font(.system(size: 32))
                .foregroundColor(Color.white.opacity(0.5)))
    }
}
