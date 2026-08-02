//
//  RenderTests.swift
//
//
//  Created by YuAo on 2021/2/2.
//

@testable import MetalPetal
import MetalPetalTestHelpers
import Testing
import VideoToolbox

private func renderedPixelBuffer(
    from renderer: MTISCNSceneRenderer,
    viewport: CGRect = CGRect(x: 0, y: 0, width: 4, height: 4),
    sRGB: Bool = true
) async throws -> CVPixelBuffer {
    try await withCheckedThrowingContinuation { continuation in
        do {
            try renderer.render(atTime: 0, viewport: viewport, sRGB: sRGB) { pixelBuffer in
                continuation.resume(returning: pixelBuffer)
            }
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

@Suite(.enabled(if: metalDeviceIsAvailable))
struct RenderTests {
    @Test func solidColorImageRendering() throws {
        let image = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 2, height: 2)
        )
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func colorInvertFilter() throws {
        let image = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 2, height: 2)
        )
        let filter = MTIColorInvertFilter()
        filter.inputImage = image
        let output = filter.outputImage
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: #require(output))
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, _ in
            #expect(pixel.r == 0 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
        }
    }

    @Test func blendWithMaskFilter() throws {
        let image = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 2, height: 2)
        )
        let backgroundImage = MTIImage(
            color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 2, height: 2)
        )
        let filter = MTIBlendWithMaskFilter()
        filter.inputBackgroundImage = backgroundImage
        filter.inputImage = image
        filter.inputMask = try MTIMask(
            content: MTIImage(cgImage: ImageGenerator.makeCheckboardImage(), isOpaque: true),
            component: .red,
            mode: .normal
        )
        let output = filter.outputImage
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: #require(output))
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func testSaturationFilter() throws {
        let image = MTIImage(
            color: MTIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1),
            sRGB: false,
            size: CGSize(width: 2, height: 2)
        )
        let filter = MTISaturationFilter()
        filter.inputImage = image
        filter.saturation = 0
        let output = filter.outputImage
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: #require(output))
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, _ in
            #expect(pixel.r == pixel.g && pixel.g == pixel.b && pixel.a == 255)
        }
    }

    @Test func intermediateTextureGeneration() throws {
        let image = MTIImage.black
        let saturationFilter = MTISaturationFilter()
        saturationFilter.saturation = 2
        let blendFilter = MTIBlendFilter(blendMode: .multiply)
        let invertFilter = MTIColorInvertFilter()
        let pixellateFilter = MTIPixellateFilter()
        pixellateFilter.scale = CGSize(width: 2, height: 2)
        let outputImage = FilterGraph.makeImage { output in
            image => saturationFilter => pixellateFilter => blendFilter.inputPorts.inputBackgroundImage
            image => invertFilter => blendFilter.inputPorts.inputImage
            blendFilter => saturationFilter => output
        }
        let context = try makeContext()
        #expect(context.idleResourceCount == 0)
        _ = try context.makeCGImage(from: #require(outputImage))
        #expect(context.idleResourceCount == 3)

        context.reclaimResources()

        #expect(context.idleResourceCount == 0)
        let outputImage2 = FilterGraph.makeImage { output in
            image => saturationFilter => pixellateFilter => invertFilter => saturationFilter => output
        }
        _ = try context.makeCGImage(from: #require(outputImage2))
        #expect(context.idleResourceCount == 2)
    }

    @Test func textureRenderResultPersistence() throws {
        let image = MTIImage.black
        let filter = MTIColorInvertFilter()
        filter.inputImage = image
        let output = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
        }

        #expect(context.idleResourceCount == 1)
        context.reclaimResources()
        #expect(context.idleResourceCount == 0)

        try autoreleasepool {
            let output2 = filter.outputImage!.withCachePolicy(.persistent)
            let outputCGImage2 = try context.makeCGImage(from: output2)
            #expect(context.idleResourceCount == 0)

            PixelEnumerator.enumeratePixels(in: outputCGImage2) { pixel, _ in
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }

            #expect(context.renderedBuffer(for: output2) != nil)

            #expect(context.idleResourceCount == 0)
        }

        #expect(context.idleResourceCount == 1)
        context.reclaimResources()
        #expect(context.idleResourceCount == 0)
    }

    @Test func coreImageFilter() throws {
        let image = MTIImage.black
        let filter = MTICoreImageUnaryFilter()
        filter.filter = CIFilter(name: "CIColorInvert")
        filter.inputImage = image
        let output = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
        }
    }

    @Test func coreImageFilter_lanczosScaleTransform() throws {
        let ciFilter = CIFilter(name: "CILanczosScaleTransform")
        ciFilter?.setValue(2, forKey: "inputScale")

        let inputImage = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 1],
            [1, 0],
        ]), isOpaque: true)

        let filter = MTICoreImageUnaryFilter()
        filter.filter = ciFilter
        filter.inputImage = inputImage
        let output = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        #expect(outputCGImage.width == Int(inputImage.size.width) * 2)
        #expect(outputCGImage.height == Int(inputImage.size.height) * 2)
        #expect(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
            [0, 0, 1, 1],
            [0, 0, 1, 1],
            [1, 1, 0, 0],
            [1, 1, 0, 0],
        ]))
    }

    @Test func pinchDistortionFilter_identity() throws {
        let inputCGImage = try ImageGenerator.makeSmoothGradientImage(width: 32, height: 32)
        let inputImage = MTIImage(cgImage: inputCGImage, isOpaque: true)

        let filter = MTIPinchDistortionFilter()
        filter.inputImage = inputImage
        filter.center = simd_make_float2(16, 16)
        filter.radius = 12
        filter.scale = 0
        let output = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        var inputPixels = [PixelEnumerator.Coordinates: PixelEnumerator.Pixel]()
        PixelEnumerator.enumeratePixels(in: inputCGImage) { pixel, coord in
            inputPixels[coord] = pixel
        }
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            #expect(pixel == inputPixels[coord])
        }
    }

    @Test func twirlDistortionFilter_identity() throws {
        let inputCGImage = try ImageGenerator.makeSmoothGradientImage(width: 32, height: 32)
        let inputImage = MTIImage(cgImage: inputCGImage, isOpaque: true)

        let filter = MTITwirlDistortionFilter()
        filter.inputImage = inputImage
        filter.center = simd_make_float2(16, 16)
        filter.radius = 12
        filter.angle = 0
        let output = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        var inputPixels = [PixelEnumerator.Coordinates: PixelEnumerator.Pixel]()
        PixelEnumerator.enumeratePixels(in: inputCGImage) { pixel, coord in
            inputPixels[coord] = pixel
        }
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            #expect(pixel == inputPixels[coord])
        }
    }

    @Test func twirlDistortionFilter_leavesPixelsOutsideRadiusUntouched() throws {
        let inputCGImage = try ImageGenerator.makeSmoothGradientImage(width: 64, height: 64)
        let inputImage = MTIImage(cgImage: inputCGImage, isOpaque: true)

        let center = simd_make_float2(32, 32)
        let radius: Float = 20
        let filter = MTITwirlDistortionFilter()
        filter.inputImage = inputImage
        filter.center = center
        filter.radius = radius
        filter.angle = .pi
        let output = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        var inputPixels = [PixelEnumerator.Coordinates: PixelEnumerator.Pixel]()
        PixelEnumerator.enumeratePixels(in: inputCGImage) { pixel, coord in
            inputPixels[coord] = pixel
        }
        var distortedPixelCount = 0
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            let dx = Float(coord.x) + 0.5 - center.x
            let dy = Float(coord.y) + 0.5 - center.y
            if (dx * dx + dy * dy).squareRoot() > radius {
                #expect(pixel == inputPixels[coord])
            } else if pixel != inputPixels[coord] {
                distortedPixelCount += 1
            }
        }
        #expect(distortedPixelCount > 100)
    }

    @Test func mPSFilter_lanczosScale() throws {
        let kernel = MTIMPSKernel { device in
            MPSImageLanczosScale(device: device)
        }
        let inputImage = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 1],
            [1, 0],
        ]), isOpaque: true)
        let scaledDimensions = MTITextureDimensions(cgSize: CGSize(
            width: inputImage.size.width * 2,
            height: inputImage.size.height * 2
        ))
        let outputImage = kernel.apply(
            toInputImages: [inputImage],
            parameters: [:],
            outputTextureDimensions: scaledDimensions,
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        if MTIContext.defaultMetalDeviceSupportsMPS {
            let outputCGImage = try context.makeCGImage(from: outputImage)
            #expect(outputCGImage.width == Int(inputImage.size.width) * 2)
            #expect(outputCGImage.height == Int(inputImage.size.height) * 2)
            #expect(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
                [0, 0, 1, 1],
                [0, 0, 1, 1],
                [1, 1, 0, 0],
                [1, 1, 0, 0],
            ]))
        }
    }

    @Test func coreImageGenerator() throws {
        let filter = try #require(CIFilter(name: "CICheckerboardGenerator"))
        filter.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        filter.setValue(CIColor.white, forKey: "inputColor0")
        filter.setValue(CIColor.black, forKey: "inputColor1")
        filter.setValue(1, forKey: "inputWidth")
        let ciImage = try #require(filter.outputImage)
        let mtiImage = MTICoreImageKernel.image(byProcessing: [], using: { _ in
            ciImage
        }, outputDimensions: MTITextureDimensions(cgSize: CGSize(width: 2, height: 2)))

        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: mtiImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }

        let mtiImageFromCIImage = MTIImage(
            ciImage: ciImage.cropped(to: CGRect(x: 0, y: 0, width: 2, height: 2)),
            isOpaque: false
        )
        let cgImage2 = try context.makeCGImage(from: mtiImageFromCIImage)
        PixelEnumerator.enumeratePixels(in: cgImage2) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func coreImageTransform() throws {
        let inputImage = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 255, 128],
        ]), isOpaque: true)
        let mtiImage = MTICoreImageKernel.image(byProcessing: [inputImage], using: { image in
            image[0].transformed(by: CGAffineTransform(translationX: -1, y: 0))
        }, outputDimensions: MTITextureDimensions(cgSize: CGSize(width: 2, height: 1)))
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: mtiImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel == PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255))
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel == PixelEnumerator.Pixel(b: 128, g: 128, r: 128, a: 255))
            }
        }
    }

    @Test func imageOrientations() throws {
        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0, 0],
            [0, 0, 255],
            [0, 255, 255],
            [0, 255, 255],
        ]), isOpaque: true)

        let context = try makeContext()
        let renderResult = try context.makeCGImage(from: image)
        #expect(PixelEnumerator.monochromeImageEqual(image: renderResult, target: [
            [0, 0, 0],
            [0, 0, 255],
            [0, 255, 255],
            [0, 255, 255],
        ]))

        // * * *
        // * *
        // *
        // *
        let up = try context.makeCGImage(from: image.oriented(.up))
        #expect(PixelEnumerator.monochromeImageEqual(image: up, target: [
            [0, 0, 0],
            [0, 0, 255],
            [0, 255, 255],
            [0, 255, 255],
        ]))

        // * * *
        //   * *
        //     *
        //     *
        let upMirrored = try context.makeCGImage(from: image.oriented(.upMirrored))
        #expect(PixelEnumerator.monochromeImageEqual(image: upMirrored, target: [
            [0, 0, 0],
            [255, 0, 0],
            [255, 255, 0],
            [255, 255, 0],
        ]))

        //     *
        //     *
        //   * *
        // * * *
        let down = try context.makeCGImage(from: image.oriented(.down))
        #expect(PixelEnumerator.monochromeImageEqual(image: down, target: [
            [255, 255, 0],
            [255, 255, 0],
            [255, 0, 0],
            [0, 0, 0],
        ]))

        // *
        // *
        // * *
        // * * *
        let downMirrored = try context.makeCGImage(from: image.oriented(.downMirrored))
        #expect(PixelEnumerator.monochromeImageEqual(image: downMirrored, target: [
            [0, 255, 255],
            [0, 255, 255],
            [0, 0, 255],
            [0, 0, 0],
        ]))

        // * * * *
        // * *
        // *
        let leftMirrored = try context.makeCGImage(from: image.oriented(.leftMirrored))
        #expect(PixelEnumerator.monochromeImageEqual(image: leftMirrored, target: [
            [0, 0, 0, 0],
            [0, 0, 255, 255],
            [0, 255, 255, 255],
        ]))

        // * * * *
        //     * *
        //       *
        let right = try context.makeCGImage(from: image.oriented(.right))
        #expect(PixelEnumerator.monochromeImageEqual(image: right, target: [
            [0, 0, 0, 0],
            [255, 255, 0, 0],
            [255, 255, 255, 0],
        ]))

        //       *
        //     * *
        // * * * *
        let rightMirrored = try context.makeCGImage(from: image.oriented(.rightMirrored))
        #expect(PixelEnumerator.monochromeImageEqual(image: rightMirrored, target: [
            [255, 255, 255, 0],
            [255, 255, 0, 0],
            [0, 0, 0, 0],
        ]))

        // *
        // * *
        // * * * *
        let left = try context.makeCGImage(from: image.oriented(.left))
        #expect(PixelEnumerator.monochromeImageEqual(image: left, target: [
            [0, 255, 255, 255],
            [0, 0, 255, 255],
            [0, 0, 0, 0],
        ]))
    }

    @Test func imageOrientations_fixture() throws {
        let context = try makeContext()
        for orientation in 1 ... 8 {
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: #file)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixture")
                .appendingPathComponent("f\(orientation).png") as CFURL, nil)
            guard let imageSource = source,
                  CGImageSourceGetCount(imageSource) > 0,
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
            else {
                Issue.record()
                return
            }
            guard let o = CGImagePropertyOrientation(rawValue: UInt32(orientation)) else {
                Issue.record()
                return
            }
            let image = MTIImage(cgImage: cgImage, isOpaque: true)
            let outputCGImage = try context.makeCGImage(from: image.oriented(o))
            #expect(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }

    @Test func multilayerCompositing() throws {
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
            .opacity(1)]
        let outputImage = try #require(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func multilayerCompositing_alpha() throws {
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
            .opacity(0.5)]
        let outputImage = try #require(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 128 && pixel.g == 128 && pixel.b == 128 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func multilayerCompositing_alphaMSAA() throws {
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 4
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
            .opacity(0.5)]
        let outputImage = try #require(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 128 && pixel.g == 128 && pixel.b == 128 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func multilayerCompositing_tint() throws {
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
            .opacity(1)
            .tintColor(MTIColor(red: 1, green: 1, blue: 0, alpha: 1))]
        let outputImage = try #require(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func colorLookupFilter() throws {
        let clut = try #require(IdentityCLUTImageGenerator
            .generateIdentityCLUTImage(with: CLUTImageDescriptor(
                dimension: 16,
                layout: CLUTImageLayout(horizontalTileCount: 1, verticalTileCount: 16)
            )))
        let invertFilter = MTIColorInvertFilter()
        invertFilter.inputImage = MTIImage(cgImage: clut, isOpaque: true)
        let clutImage = try #require(invertFilter.outputImage)

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [64, 128],
        ]), isOpaque: true)

        let lookupFilter = MTIColorLookupFilter()
        lookupFilter.inputImage = image
        lookupFilter.inputColorLookupTable = clutImage
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: #require(lookupFilter.outputImage))
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 191 && pixel.g == 191 && pixel.b == 191 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 127 && pixel.g == 127 && pixel.b == 127 && pixel.a == 255)
            }
        }
    }

    @Test func multilayerCompositing_clut512x512() throws {
        let clut = try #require(IdentityCLUTImageGenerator
            .generateIdentityCLUTImage(with: CLUTImageDescriptor(
                dimension: 64,
                layout: CLUTImageLayout(horizontalTileCount: 8, verticalTileCount: 8)
            )))
        let invertFilter = MTIColorInvertFilter()
        invertFilter.inputImage = MTIImage(cgImage: clut, isOpaque: true)
        let clutImage = try #require(invertFilter.outputImage)

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [64, 64],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: clutImage)
            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
            .opacity(1)
            .blendMode(.colorLookup512x512)]
        let outputImage = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 191 && pixel.g == 191 && pixel.b == 191 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 64 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
            }
        }
    }

    @Test func multilayerCompositing_mask() throws {
        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [128, 128],
            [128, 128],
        ]), isOpaque: true)

        let mask = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [255, 0],
        ]), isOpaque: true)

        let layerContent = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: layerContent)
            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
            .opacity(1)
            .blendMode(.normal)
            .mask(MTIMask(content: mask))]
        let outputImage = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        #expect(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
            [0, 128],
            [128, 128],
        ]))
    }

    @Test func multilayerCompositing_compositingMask() throws {
        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [128, 128],
            [128, 128],
        ]), isOpaque: true)

        let compositingMask = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 255],
            [0, 0],
        ]), isOpaque: true)

        let layerContent = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: layerContent)
            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
            .opacity(1)
            .blendMode(.normal)
            .compositingMask(MTIMask(content: compositingMask))]
        let outputImage = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        #expect(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
            [128, 0],
            [128, 128],
        ]))
    }

    @Test func multilayerCompositing_clut512x512_mask() throws {
        let clut = try #require(IdentityCLUTImageGenerator
            .generateIdentityCLUTImage(with: CLUTImageDescriptor(
                dimension: 64,
                layout: CLUTImageLayout(horizontalTileCount: 8, verticalTileCount: 8)
            )))
        let invertFilter = MTIColorInvertFilter()
        invertFilter.inputImage = MTIImage(cgImage: clut, isOpaque: true)
        let clutImage = try #require(invertFilter.outputImage)

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [64, 64],
            [64, 64],
        ]), isOpaque: true)

        let mask = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [255, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: clutImage)
            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
            .opacity(1)
            .blendMode(.colorLookup512x512)
            .mask(MTIMask(content: mask))]
        let outputImage = try #require(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        #expect(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
            [191, 64],
            [64, 64],
        ]))
    }

    @Test func multilayerCompositing_tintWithAlpha() throws {
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image

        try autoreleasepool {
            filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                .opacity(1)
                .tintColor(MTIColor(red: 1, green: 1, blue: 0, alpha: 0.5))]
            let outputImage = try #require(filter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
                if coord.x == 0, coord.y == 0 {
                    #expect(pixel.r == 128 && pixel.g == 128 && pixel.b == 0 && pixel.a == 255)
                }
                if coord.x == 1, coord.y == 0 {
                    #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
                }
            }
        }

        try autoreleasepool {
            filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                .opacity(1)
                .tintColor(MTIColor(red: 1, green: 1, blue: 0, alpha: 0))]
            let outputImage = try #require(filter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
                if coord.x == 0, coord.y == 0 {
                    #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
                }
                if coord.x == 1, coord.y == 0 {
                    #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
                }
            }
        }
    }

    @Test func multilayerCompositing_rotation() throws {
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
            [0, 0],
        ]), isOpaque: true)

        let overlayImage = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 255],
            [0, 0],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: overlayImage)
            .frame(CGRect(x: 0, y: 0, width: 2, height: 2), layoutUnit: .pixel)
            .rotation(.pi / 2)
            .opacity(1)]
        guard let outputImage = filter.outputImage else {
            Issue.record()
            return
        }
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 0, coord.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func multilayerCompositing_outputOpaqueImage() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        ))
        .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
        .opacity(1)]
        filter.outputAlphaType = .alphaIsOne
        let outputImage = try #require(filter.outputImage?.withCachePolicy(.persistent))
        #expect(outputImage.alphaType == .alphaIsOne)

        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func multilayerCompositing_outputNonPremultipliedAlpha() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        ))
        .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
        .opacity(1)]
        let outputImage = try #require(filter.outputImage?.withCachePolicy(.persistent))
        #expect(outputImage.alphaType == .nonPremultiplied)

        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try #require(context.renderedBuffer(for: outputImage))
        let texture = try #require(buffer.renderedTexture)
        let pixels = try fetchFirstPixel(from: texture, context: context)
        #expect(pixels == [0, 0, 255, 192])
    }

    @Test func multilayerCompositing_outputPremultipliedAlpha() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        ))
        .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
        .opacity(1)]
        filter.outputAlphaType = .premultiplied
        let outputImage = try #require(filter.outputImage?.withCachePolicy(.persistent))
        #expect(outputImage.alphaType == .premultiplied)

        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try #require(context.renderedBuffer(for: outputImage))
        let texture = try #require(buffer.renderedTexture)
        let pixels = try fetchFirstPixel(from: texture, context: context)
        #expect(pixels == [0, 0, 192, 192])
    }

    @Test func blend_outputOpaqueImage() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        ))
        .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
        .opacity(1)]
        filter.outputAlphaType = .alphaIsOne
        let outputImage = try #require(filter.outputImage?.withCachePolicy(.persistent))
        #expect(outputImage.alphaType == .alphaIsOne)

        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func blend_outputNonPremultipliedAlpha() throws {
        let filter = MTIBlendFilter(blendMode: .normal)
        filter.inputBackgroundImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        filter.inputImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = try #require(filter.outputImage?.withCachePolicy(.persistent))
        #expect(outputImage.alphaType == .nonPremultiplied)
        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try #require(context.renderedBuffer(for: outputImage))
        let texture = try #require(buffer.renderedTexture)
        let pixels = try fetchFirstPixel(from: texture, context: context)
        #expect(pixels == [0, 0, 255, 192])
    }

    @Test func blend_outputPremultipliedAlpha() throws {
        let filter = MTIBlendFilter(blendMode: .normal)
        filter.inputBackgroundImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        filter.inputImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        filter.outputAlphaType = .premultiplied
        let outputImage = try #require(filter.outputImage?.withCachePolicy(.persistent))
        #expect(outputImage.alphaType == .premultiplied)

        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try #require(context.renderedBuffer(for: outputImage))
        let texture = try #require(buffer.renderedTexture)
        let pixels = try fetchFirstPixel(from: texture, context: context)
        #expect(pixels == [0, 0, 192, 192])
    }

    @Test func multilayerCompositing_outputPremultipliedAlpha_emptyLayers() throws {
        let kernel = MTIMultilayerCompositeKernel()
        let outputImage = kernel.apply(
            toBackgroundImage: MTIImage(
                color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
                sRGB: false,
                size: CGSize(width: 1, height: 1)
            ),
            layers: [],
            rasterSampleCount: 1,
            outputAlphaType: .premultiplied,
            outputTextureDimensions: .init(width: 1, height: 1, depth: 1),
            outputPixelFormat: .unspecified
        ).withCachePolicy(.persistent)
        #expect(outputImage.alphaType == .premultiplied)

        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try #require(context.renderedBuffer(for: outputImage))
        let texture = try #require(buffer.renderedTexture)
        let pixels = try fetchFirstPixel(from: texture, context: context)
        #expect(pixels == [0, 0, 128, 128])
    }

    @Test func multilayerCompositing_outputPremultipliedAlpha_msaa() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage(
            color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        ))
        .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
        .opacity(1)]
        filter.rasterSampleCount = 4
        filter.outputAlphaType = .premultiplied
        let outputImage = try #require(filter.outputImage?.withCachePolicy(.persistent))
        #expect(outputImage.alphaType == .premultiplied)

        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try #require(context.renderedBuffer(for: outputImage))
        let texture = try #require(buffer.renderedTexture)
        let pixels = try fetchFirstPixel(from: texture, context: context)
        #expect(pixels == [0, 0, 192, 192])
    }

    @Test func mSAA_multilayerCompositing() throws {
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
            .frame(CGRect(x: 0, y: 0, width: 1.6, height: 1), layoutUnit: .pixel)
            .opacity(1)]
        guard let outputImage = filter.outputImage else {
            Issue.record()
            return
        }
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
        filter.rasterSampleCount = 4
        guard let outputImageMSAA = filter.outputImage else {
            Issue.record()
            return
        }
        let outputCGImageMSAA = try context.makeCGImage(from: outputImageMSAA)
        PixelEnumerator.enumeratePixels(in: outputCGImageMSAA) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                let positions = context.device.getDefaultSamplePositions(sampleCount: 4)
                var p: Double = 0
                for position in positions where position.x < 0.6 {
                    p += 1.0 / 4.0
                }
                let value = UInt8(round(p * 255))
                #expect(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }

    @Test func mSAA_renderCommand() throws {
        let context = try makeContext()
        let geometry = MTIVertices.squareVertices(for: CGRect(x: -1, y: -1, width: 1.6, height: 2))
        let command = MTIRenderCommand(
            kernel: .passthrough,
            geometry: geometry,
            images: [MTIImage.white],
            parameters: [:]
        )
        let outputDescriptor = MTIRenderPassOutputDescriptor(
            dimensions: MTITextureDimensions(width: 2, height: 1, depth: 1),
            pixelFormat: .bgra8Unorm,
            clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1),
            loadAction: .clear,
            storeAction: .store
        )
        let image = MTIRenderCommand.images(
            byPerforming: [command],
            rasterSampleCount: 1,
            outputDescriptors: [outputDescriptor]
        ).first
        guard let outputImage = image else {
            Issue.record()
            return
        }
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
        let imageMSAA = MTIRenderCommand.images(
            byPerforming: [command],
            rasterSampleCount: 4,
            outputDescriptors: [outputDescriptor]
        ).first
        guard let outputImageMSAA = imageMSAA else {
            Issue.record()
            return
        }
        let outputCGImageMSAA = try context.makeCGImage(from: outputImageMSAA)
        PixelEnumerator.enumeratePixels(in: outputCGImageMSAA) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                let positions = context.device.getDefaultSamplePositions(sampleCount: 4)
                var p: Double = 0
                for position in positions where position.x < 0.6 {
                    p += 1.0 / 4.0
                }
                let value = UInt8(round(p * 255))
                #expect(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }

    @Test func testRenderedBuffer() throws {
        let context = try makeContext()
        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [255, 255],
            [0, 255],
        ]), isOpaque: true)

        let filter1 = MTIColorInvertFilter()
        filter1.inputImage = image

        let filter2 = MTITransformFilter()
        filter2.transform = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
        filter2.inputImage = filter1.outputImage

        var renderedBuffer: MTIImage!

        try autoreleasepool {
            let outputImage = try #require(filter2.outputImage?.withCachePolicy(.persistent))

            #expect(context.renderedBuffer(for: outputImage) == nil)

            _ = try context.startTask(toRender: outputImage, completion: nil)

            #expect(context.renderedBuffer(for: outputImage) != nil)

            let buffer = try #require(context.renderedBuffer(for: outputImage))

            renderedBuffer = buffer

            #expect(context.idleResourceCount == 1)
        }

        context.reclaimResources()

        #expect(context.idleResourceCount == 0)

        let outputCGImage = try context.makeCGImage(from: renderedBuffer)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 0, coord.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }

        #expect(context.idleResourceCount == 0)

        renderedBuffer = nil

        #expect(context.idleResourceCount == 1)

        context.reclaimResources()

        #expect(context.idleResourceCount == 0)
    }

    @Test func customComputePipeline() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testCompute(
        texture2d<float, access::read> inTexture [[texture(0)]],
        texture2d<float, access::write> outTexture [[texture(1)]],
        constant float4 &color [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
                return;
            }
            outTexture.write(inTexture.read(uint2(0,0)) + color, gid);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: kernelSource,
            compileOptions: nil
        )
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
            name: "testCompute",
            libraryURL: libraryURL
        ))

        try autoreleasepool {
            let image = MTIImage(
                color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
                sRGB: false,
                size: CGSize(width: 32, height: 32)
            )
            let outputImage = computeKernel.apply(
                toInputImages: [image],
                parameters: ["color": .vector(MTIVector(value: SIMD4<Float>(1, 0, 0, 0)))],
                dispatchOptions: nil,
                outputTextureDimensions: image.dimensions,
                outputPixelFormat: .unspecified
            )
            let context = try makeContext()
            let output = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }

        try autoreleasepool {
            let image = MTIImage(
                color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
                sRGB: false,
                size: CGSize(width: 1, height: 1)
            )
            let outputImage = computeKernel.apply(
                toInputImages: [image],
                parameters: ["color": .vector(MTIVector(value: SIMD4<Float>(1, 0, 0, 0)))],
                dispatchOptions: nil,
                outputTextureDimensions: image.dimensions,
                outputPixelFormat: .unspecified
            )
            let context = try makeContext()
            let output = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func customComputePipelineWithFunctionConstants() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        constant float4 constColor [[function_constant(0)]];

        kernel void testCompute(
        texture2d<float, access::read> inTexture [[texture(0)]],
        texture2d<float, access::write> outTexture [[texture(1)]],
        uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
                return;
            }
            outTexture.write(inTexture.read(uint2(0,0)) + constColor, gid);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: kernelSource,
            compileOptions: nil
        )
        let constantValues = MTLFunctionConstantValues()
        var color = SIMD4<Float>(1, 0, 0, 0)
        constantValues.setConstantValue(&color, type: .float4, withName: "constColor")
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
            name: "testCompute",
            constantValues: constantValues,
            libraryURL: libraryURL
        ))

        try autoreleasepool {
            let image = MTIImage(
                color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
                sRGB: false,
                size: CGSize(width: 32, height: 32)
            )
            let outputImage = computeKernel.apply(
                toInputImages: [image],
                parameters: [:],
                dispatchOptions: nil,
                outputTextureDimensions: image.dimensions,
                outputPixelFormat: .unspecified
            )
            let context = try makeContext()
            let output = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }

        try autoreleasepool {
            let image = MTIImage(
                color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
                sRGB: false,
                size: CGSize(width: 1, height: 1)
            )
            let outputImage = computeKernel.apply(
                toInputImages: [image],
                parameters: [:],
                dispatchOptions: nil,
                outputTextureDimensions: image.dimensions,
                outputPixelFormat: .unspecified
            )
            let context = try makeContext()
            let output = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func customRenderPipeline() throws {
        var librarySource = ""
        let sourceFileDirectory = URL(fileURLWithPath: String(#file)).deletingLastPathComponent()
            .appendingPathComponent("../../Sources/MetalPetal/Shaders")
        let headerURL = sourceFileDirectory.appendingPathComponent("MTIShaderLib.h")
        librarySource += try String(contentsOf: headerURL)
        librarySource += """

        using namespace metalpetal;

        fragment float4 testRender(
                                VertexOut vertexIn [[stage_in]],
                                texture2d<float, access::sample> sourceTexture [[texture(0)]],
                                sampler sourceSampler [[sampler(0)]],
                                constant float4 &color [[buffer(0)]]
                                ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            return textureColor + color;
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: librarySource,
            compileOptions: nil
        )
        let renderKernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "testRender", libraryURL: libraryURL)
        )
        let image = MTIImage(
            color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = renderKernel.apply(
            to: [image],
            parameters: ["color": .vector(MTIVector(value: SIMD4<Float>(1, 0, 0, 0)))],
            outputDimensions: image.dimensions,
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func customRenderPipelineWithFunctionConstants() throws {
        var librarySource = ""
        let sourceFileDirectory = URL(fileURLWithPath: String(#file)).deletingLastPathComponent()
            .appendingPathComponent("../../Sources/MetalPetal/Shaders")
        let headerURL = sourceFileDirectory.appendingPathComponent("MTIShaderLib.h")
        librarySource += try String(contentsOf: headerURL)
        librarySource += """

        using namespace metalpetal;

        constant float4 constColor [[function_constant(0)]];

        fragment float4 testRender(
            VertexOut vertexIn [[stage_in]],
            texture2d<float, access::sample> sourceTexture [[texture(0)]],
            sampler sourceSampler [[sampler(0)]]
        ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            return textureColor + constColor;
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: librarySource,
            compileOptions: nil
        )
        let constantValues = MTLFunctionConstantValues()
        var color = SIMD4<Float>(1, 0, 0, 0)
        constantValues.setConstantValue(&color, type: .float4, withName: "constColor")
        let renderKernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: MTIFunctionDescriptor(
                name: "testRender",
                constantValues: constantValues,
                libraryURL: libraryURL
            )
        )
        let image = MTIImage(
            color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = renderKernel.apply(
            to: [image],
            parameters: [:],
            outputDimensions: image.dimensions,
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func multilayerCompositing_customBlending() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float4 blend(float4 background, float4 foreground) {
            return background + foreground;
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [64, 64],
        ]), isOpaque: true)

        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage(
            color: MTIColor(red: 64 / 255.0, green: 0, blue: 0, alpha: 0),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        ))
        .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
        .opacity(1)
        .blendMode(blendMode)]
        let outputImage = try #require(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 128 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 64 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
            }
        }
    }

    @Test func multilayerCompositing_customBlending_textureCoordinatesModifier() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float2 modify_source_texture_coordinates(float4 backdrop, float2 coordinates, uint2 source_texture_size) {
            return float2(1.5, 0.5) / float2(source_texture_size);
        }
        float4 blend(float4 background, float4 foreground) {
            return background + foreground;
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [64, 64],
        ]), isOpaque: true)
        let overlay = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 32],
        ]), isOpaque: true)
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [MultilayerCompositingFilter.Layer(content: overlay)
            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
            .opacity(1)
            .blendMode(blendMode)]
        let outputImage = try #require(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
            if coord.x == 0, coord.y == 0 {
                #expect(pixel.r == 64 + 32 && pixel.g == 64 + 32 && pixel.b == 64 + 32 && pixel.a == 255)
            }
            if coord.x == 1, coord.y == 0 {
                #expect(pixel.r == 64 + 32 && pixel.g == 64 + 32 && pixel.b == 64 + 32 && pixel.a == 255)
            }
        }
    }

    @Test func multilayerCompositing_blendModeRenderPipelineNotFound() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [64, 64],
        ]), isOpaque: true)
        let overlay = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 32],
        ]), isOpaque: true)
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [MultilayerCompositingFilter.Layer(content: overlay)
            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
            .opacity(1)
            .blendMode(blendMode)]
        let outputImage = try #require(filter.outputImage)
        #expect(throws: (any Error).self) { try context.makeCGImage(from: outputImage) }
    }

    @Test func customBlending() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float4 blend(float4 background, float4 foreground) {
            return background + foreground;
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }
        let context = try makeContext()
        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([[64]]), isOpaque: true)
        let overlay = MTIImage(
            color: MTIColor(red: 64 / 255.0, green: 0, blue: 0, alpha: 0),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let blendFilter = MTIBlendFilter(blendMode: blendMode)
        blendFilter.inputBackgroundImage = image
        blendFilter.inputImage = overlay
        do {
            let outputImage = try #require(blendFilter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
                if coord.x == 0, coord.y == 0 {
                    #expect(pixel.r == 128 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
                }
            }
        }
        do {
            blendFilter.intensity = 0.5
            let outputImage = try #require(blendFilter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
                if coord.x == 0, coord.y == 0 {
                    #expect(pixel.r == 64 + 32 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
                }
            }
        }
    }

    @Test func customBlending_textureCoordinatesModifier() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float2 modify_source_texture_coordinates(float4 backdrop, float2 coordinates, uint2 source_texture_size) {
            return float2(1.5, 0.5) / float2(source_texture_size);
        }
        float4 blend(float4 background, float4 foreground) {
            return background + foreground;
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }
        let context = try makeContext()

        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [64],
        ]), isOpaque: true)
        let overlay = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [0, 32],
        ]), isOpaque: true)
        let blendFilter = MTIBlendFilter(blendMode: blendMode)
        blendFilter.inputBackgroundImage = image
        blendFilter.inputImage = overlay

        do {
            let outputImage = try #require(blendFilter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
                if coord.x == 0, coord.y == 0 {
                    #expect(pixel.r == 64 + 32 && pixel.g == 64 + 32 && pixel.b == 64 + 32 && pixel.a == 255)
                }
            }
        }

        do {
            blendFilter.intensity = 0.5
            let outputImage = try #require(blendFilter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coord in
                if coord.x == 0, coord.y == 0 {
                    #expect(pixel.r == 64 + 16 && pixel.g == 64 + 16 && pixel.b == 64 + 16 && pixel.a == 255)
                }
            }
        }
    }

    @Test func customBlending_failure() throws {
        do {
            let name = "customBlend" + String(#line)
            let blendMode = MTIBlendMode(rawValue: name)
            MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
            void blend(float4 background, float4 foreground) {
                return background + foreground;
            }
            """))
            defer {
                MTIBlendModes.unregisterBlendMode(blendMode)
            }
            let context = try makeContext()
            let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([[64]]), isOpaque: true)
            let overlay = MTIImage(
                color: MTIColor(red: 64 / 255.0, green: 0, blue: 0, alpha: 0),
                sRGB: false,
                size: CGSize(width: 1, height: 1)
            )
            let blendFilter = MTIBlendFilter(blendMode: blendMode)
            blendFilter.inputBackgroundImage = image
            blendFilter.inputImage = overlay
            do {
                let outputImage = try #require(blendFilter.outputImage)
                #expect(throws: (any Error).self) { try context.makeCGImage(from: outputImage) }
            }
        }

        do {
            let name = "customBlend" + String(#line)
            let blendMode = MTIBlendMode(rawValue: name)
            MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
            float4 my_blend(float4 background, float4 foreground) {
                return background + foreground;
            }
            """))
            defer {
                MTIBlendModes.unregisterBlendMode(blendMode)
            }
            let context = try makeContext()
            let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([[64]]), isOpaque: true)
            let overlay = MTIImage(
                color: MTIColor(red: 64 / 255.0, green: 0, blue: 0, alpha: 0),
                sRGB: false,
                size: CGSize(width: 1, height: 1)
            )
            let blendFilter = MTIBlendFilter(blendMode: blendMode)
            blendFilter.inputBackgroundImage = image
            blendFilter.inputImage = overlay
            do {
                let outputImage = try #require(blendFilter.outputImage)
                #expect(throws: (any Error).self) { try context.makeCGImage(from: outputImage) }
            }
        }

        do {
            let name = "customBlend" + String(#line)
            let blendMode = MTIBlendMode(rawValue: name)
            MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
            int modify_source_texture_coordinates = 0;
            float4 my_blend(float4 background, float4 foreground) {
                return background + foreground;
            }
            """))
            defer {
                MTIBlendModes.unregisterBlendMode(blendMode)
            }
            let context = try makeContext()
            let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([[64]]), isOpaque: true)
            let overlay = MTIImage(
                color: MTIColor(red: 64 / 255.0, green: 0, blue: 0, alpha: 0),
                sRGB: false,
                size: CGSize(width: 1, height: 1)
            )
            let blendFilter = MTIBlendFilter(blendMode: blendMode)
            blendFilter.inputBackgroundImage = image
            blendFilter.inputImage = overlay
            do {
                let outputImage = try #require(blendFilter.outputImage)
                #expect(throws: (any Error).self) { try context.makeCGImage(from: outputImage) }
            }
        }
    }

    @Test func cropFilter() throws {
        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12],
            [13, 14, 15, 16],
        ]), isOpaque: true)
        do {
            let croppedImage = image.cropped(to: .pixel(CGRect(x: 0, y: 0, width: 0, height: 0)))
            #expect(croppedImage == nil)
        }
        do {
            let croppedImage = image.cropped(to: .fractional(CGRect(x: 0, y: 0, width: 0, height: 0)))
            #expect(croppedImage == nil)
        }
        do {
            let croppedImage = try #require(image.cropped(to: .pixel(CGRect(
                x: 1,
                y: 1,
                width: 1,
                height: 1
            ))))
            let context = try makeContext()
            let output = try context.makeCGImage(from: croppedImage)
            PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
                #expect(pixel.r == 6 && pixel.g == 6 && pixel.b == 6 && pixel.a == 255)
            }
        }
        do {
            let croppedImage = try #require(image.cropped(to: .pixel(CGRect(
                x: 1,
                y: 1,
                width: 100,
                height: 100
            ))))
            #expect(croppedImage.size.width == 100 && croppedImage.size.height == 100)
        }
    }

    @Test func writeToDataBuffer() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testCompute(device uint *outBuffer [[buffer(0)]],
                                constant uint &count [[buffer(1)]],
                                uint gid [[thread_position_in_grid]]) {
            if (gid < count) {
                outBuffer[gid] = gid;
            }
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: kernelSource,
            compileOptions: nil
        )
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
            name: "testCompute",
            constantValues: nil,
            libraryURL: libraryURL
        ))
        do {
            let dataCount = 8
            let dataBuffer = try #require(MTIDataBuffer(
                data: Data(count: dataCount * MemoryLayout<UInt32>.stride),
                options: []
            ))
            let outputImage = computeKernel.apply(
                toInputImages: [],
                parameters: ["outBuffer": .dataBuffer(dataBuffer),
                             "count": .vector(MTIVector(values: [UInt32(dataCount)]))],
                dispatchOptions: nil,
                outputTextureDimensions: MTITextureDimensions(width: dataCount, height: 1),
                outputPixelFormat: .unspecified
            )
            let context = try makeContext()
            let task = try context.startTask(toRender: outputImage, completion: { _ in
            })
            task.waitUntilCompleted()
            dataBuffer.unsafeAccess { (pointer: UnsafeMutableRawPointer, length: Int) in
                let count = length / MemoryLayout<UInt32>.stride
                let output = Array(UnsafeBufferPointer(
                    start: pointer.bindMemory(to: UInt32.self, capacity: count),
                    count: count
                ))
                #expect(output.count == dataCount)
                for item in output.enumerated() {
                    #expect(item.element == UInt32(item.offset))
                }
            }
        }
    }

    @Test func sKSceneRender() throws {
        let scene = SKScene(size: CGSize(width: 32, height: 32))

        let node1 = SKShapeNode(circleOfRadius: 16)
        node1.fillColor = .red
        node1.lineWidth = 1
        node1.strokeColor = .white
        scene.addChild(node1)

        let node2 = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 32, height: 32))
        node2.fillColor = .blue
        node2.lineWidth = 0
        scene.addChild(node2)

        let node3 = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 32, height: 16))
        node3.fillColor = .green
        node3.lineWidth = 0
        scene.addChild(node3)

        let image = MTIImage(skScene: scene)
        let context = try makeContext()
        let output = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: output) { pixel, coord in
            if coord.y < 16 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 255 && pixel.a == 255)
            } else {
                #expect(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }

    @Test func sCNSceneRender() throws {
        let scene = SCNScene()

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)

        let cubeNode = SCNNode()
        cubeNode.geometry = SCNBox(width: 20, height: 20, length: 20, chamferRadius: 0)
        cubeNode.geometry?.firstMaterial?.lightingModel = .constant
        var color: [CGFloat] = [0, 0, 0.5, 1]
        cubeNode.geometry?.firstMaterial?.diffuse.contents = CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: &color
        )
        cubeNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(cubeNode)

        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        var whiteColor: [CGFloat] = [1, 1, 1, 1]
        ambientLightNode.light?.color = try #require(CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: &whiteColor
        ))
        scene.rootNode.addChildNode(ambientLightNode)

        let context = try makeContext()
        let renderer = MTISCNSceneRenderer(device: context.device)
        renderer.scene = scene
        renderer.scnRenderer.pointOfView = cameraNode
        let image = renderer.snapshot(
            atTime: CFAbsoluteTimeGetCurrent(),
            viewport: CGRect(x: 0, y: 0, width: 32, height: 32),
            pixelFormat: .unspecified,
            isOpaque: true
        )
        let sRGBImage = MTILinearToSRGBToneCurveFilter.image(byProcessingImage: image)
        let output = try context.makeCGImage(from: sRGBImage)
        PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
            #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 128 && pixel.a == 255)
        }
    }

    @Test func sCNSceneRender_msaa() throws {
        let scene = SCNScene()

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 16)

        let cubeNode = SCNNode()
        cubeNode.geometry = SCNBox(width: 8, height: 8, length: 8, chamferRadius: 0)
        cubeNode.geometry?.firstMaterial?.lightingModel = .constant
        var color: [CGFloat] = [1, 1, 1, 1]
        cubeNode.geometry?.firstMaterial?.diffuse.contents = CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: &color
        )
        cubeNode.position = SCNVector3(x: 0, y: 0, z: 0)
        cubeNode.rotation = SCNVector4(x: 0, y: 0, z: 1, w: .pi / 4)
        scene.rootNode.addChildNode(cubeNode)

        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        var whiteColor: [CGFloat] = [1, 1, 1, 1]
        ambientLightNode.light?.color = try #require(CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: &whiteColor
        ))
        scene.rootNode.addChildNode(ambientLightNode)

        let context = try makeContext()

        let renderer = MTISCNSceneRenderer(device: context.device)
        renderer.scene = scene
        renderer.scnRenderer.pointOfView = cameraNode
        do {
            // With MSAA
            renderer.antialiasingMode = .multisampling4X
            let image = renderer.snapshot(
                atTime: 0,
                viewport: CGRect(x: 0, y: 0, width: 4, height: 4),
                pixelFormat: .unspecified,
                isOpaque: false
            ).unpremultiplyingAlpha()
            let sRGBImage = MTILinearToSRGBToneCurveFilter.image(byProcessingImage: image)
            let output = try context.makeCGImage(from: sRGBImage)
            let result: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [
                PixelEnumerator.Coordinates(x: 0, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 2): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 0, y: 2): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 2, y: 2): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 1, y: 2): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 3, y: 1): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 2, y: 1): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 0, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 3): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 3, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 3): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 1, y: 1): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 1, y: 0): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 2, y: 0): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 0, y: 1): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 3, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
            ]
            PixelEnumerator.enumeratePixels(in: output) { pixel, coord in
                #expect(result[coord] == pixel)
            }
        } catch {
            throw error
        }

        do {
            // Without MSAA
            renderer.antialiasingMode = .none
            let image = renderer.snapshot(
                atTime: 0,
                viewport: CGRect(x: 0, y: 0, width: 4, height: 4),
                pixelFormat: .unspecified,
                isOpaque: false
            ).unpremultiplyingAlpha()
            let sRGBImage = MTILinearToSRGBToneCurveFilter.image(byProcessingImage: image)
            let output = try context.makeCGImage(from: sRGBImage)
            let result: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [
                PixelEnumerator.Coordinates(x: 0, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 2): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 0, y: 2): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 2): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 1, y: 2): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 3, y: 1): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 1): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 0, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 1): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 1, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 0, y: 1): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
            ]
            PixelEnumerator.enumeratePixels(in: output) { pixel, coord in
                #expect(result[coord] == pixel)
            }
        } catch {
            throw error
        }
    }

    @Test func sCNSceneRender_msaa_pixelbuffer() async throws {
        let scene = SCNScene()
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 16)
        let cubeNode = SCNNode()
        cubeNode.geometry = SCNBox(width: 8, height: 8, length: 8, chamferRadius: 0)
        cubeNode.geometry?.firstMaterial?.lightingModel = .constant
        var color: [CGFloat] = [1, 1, 1, 1]
        cubeNode.geometry?.firstMaterial?.diffuse.contents = CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: &color
        )
        cubeNode.position = SCNVector3(x: 0, y: 0, z: 0)
        cubeNode.rotation = SCNVector4(x: 0, y: 0, z: 1, w: .pi / 4)
        scene.rootNode.addChildNode(cubeNode)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        var whiteColor: [CGFloat] = [1, 1, 1, 1]
        ambientLightNode.light?.color = try #require(CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: &whiteColor
        ))
        scene.rootNode.addChildNode(ambientLightNode)
        let context = try makeContext()
        let renderer = MTISCNSceneRenderer(device: context.device)
        renderer.scene = scene
        renderer.scnRenderer.pointOfView = cameraNode
        do {
            // With MSAA
            renderer.antialiasingMode = .multisampling4X
            let pixelBuffer = try await renderedPixelBuffer(from: renderer)
            var cgImage: CGImage!
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
            let result: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [
                PixelEnumerator.Coordinates(x: 0, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 2): PixelEnumerator.Pixel(
                    b: 64,
                    g: 64,
                    r: 64,
                    a: 64
                ),
                PixelEnumerator.Coordinates(x: 0, y: 2): PixelEnumerator.Pixel(
                    b: 64,
                    g: 64,
                    r: 64,
                    a: 64
                ),
                PixelEnumerator.Coordinates(x: 2, y: 2): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 1, y: 2): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 3, y: 1): PixelEnumerator.Pixel(
                    b: 64,
                    g: 64,
                    r: 64,
                    a: 64
                ),
                PixelEnumerator.Coordinates(x: 2, y: 1): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 0, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 3): PixelEnumerator.Pixel(
                    b: 64,
                    g: 64,
                    r: 64,
                    a: 64
                ),
                PixelEnumerator.Coordinates(x: 3, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 3): PixelEnumerator.Pixel(
                    b: 64,
                    g: 64,
                    r: 64,
                    a: 64
                ),
                PixelEnumerator.Coordinates(x: 1, y: 1): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 1, y: 0): PixelEnumerator.Pixel(
                    b: 64,
                    g: 64,
                    r: 64,
                    a: 64
                ),
                PixelEnumerator.Coordinates(x: 2, y: 0): PixelEnumerator.Pixel(
                    b: 64,
                    g: 64,
                    r: 64,
                    a: 64
                ),
                PixelEnumerator.Coordinates(x: 0, y: 1): PixelEnumerator.Pixel(
                    b: 64,
                    g: 64,
                    r: 64,
                    a: 64
                ),
                PixelEnumerator.Coordinates(x: 3, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
            ]
            PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coord in
                guard let expected = result[coord] else {
                    Issue.record("Unexpected coordinates \(coord)")
                    return
                }
                if expected.a == 0 || expected.a == 255 {
                    #expect(expected == pixel)
                } else {
                    // Partially covered edge pixel. Its color channels depend on the space in
                    // which the GPU resolves the multisampled sRGB render target: averaging the
                    // sRGB encoded samples yields 64, converting the samples to linear and
                    // re-encoding the average yields 137. Both occur in practice.
                    #expect(pixel.a == expected.a)
                    #expect(pixel.b == pixel.g && pixel.g == pixel.r)
                    #expect(pixel.b == expected.b || pixel.b == 137)
                }
            }
        }
        renderer.antialiasingMode = .none
        let pixelBuffer = try await renderedPixelBuffer(from: renderer)
        do {
            var cgImage: CGImage!
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
            let result: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [
                PixelEnumerator.Coordinates(x: 0, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 2): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 0, y: 2): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 2): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 1, y: 2): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 3, y: 1): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 1): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 0, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 1): PixelEnumerator.Pixel(
                    b: 255,
                    g: 255,
                    r: 255,
                    a: 255
                ),
                PixelEnumerator.Coordinates(x: 1, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 0, y: 1): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
            ]
            PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coord in
                #expect(result[coord] == pixel)
            }
        }
    }

    @Test func yCbCrTextureSupport() throws {
        let context = try makeContext()
        if context.isYCbCrPixelFormatSupported {
            let blueImage = MTIImage(
                color: MTIColor(red: 0, green: 0, blue: 1, alpha: 1),
                sRGB: false,
                size: CGSize(width: 4, height: 4)
            )
            var pixelBuffer: CVPixelBuffer!
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                4,
                4,
                kCVPixelFormatType_420YpCbCr10BiPlanarFullRange,
                [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
                &pixelBuffer
            )
            try CVBufferSetAttachment(
                pixelBuffer,
                kCVImageBufferCGColorSpaceKey,
                #require(CGColorSpace(name: CGColorSpace.sRGB)),
                .shouldPropagate
            )
            try context.render(blueImage, to: pixelBuffer)
            var cgImage: CGImage!
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
            var pixels = [UInt8](repeating: 0, count: 4 * 4 * 4)
            let cgContext = try CGContext(
                data: &pixels,
                width: 4,
                height: 4,
                bitsPerComponent: 8,
                bytesPerRow: 4 * 4,
                space: #require(CGColorSpace(name: CGColorSpace.sRGB)),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst
                    .rawValue
            )
            cgContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: 4, height: 4))
            for i in 0 ..< pixels.count where i % 4 == 0 {
                // The 10-bit 4:2:0 YCbCr round trip lands on 254 or 255 depending on how the
                // conversion rounds, so allow either.
                #expect(pixels[i] >= 254) // b
                #expect(pixels[i + 1] == 0) // g
                #expect(pixels[i + 2] == 0) // r
                #expect(pixels[i + 3] == 255) // a
            }
        }
    }

    @Test func testLinearToSRGB() throws {
        let inputValue: Float = 128.0 / 255.0
        let image = MTIImage(
            color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(
            image,
            from: .linearSRGB,
            to: .sRGB,
            alphaType: .nonPremultiplied,
            pixelFormat: .unspecified
        )
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(round(
                    ((c < 0.0031308) ? (12.92 * c) : (1.055 * pow(c, 1.0 / 2.4) - 0.055)) * 255.0
                ))
                #expect(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }

    @Test func linearToSRGB_outputPremultipliedAlpha() throws {
        let inputValue: Float = 128.0 / 255.0
        let image = MTIImage(
            color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 0.5),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(
            image,
            from: .linearSRGB,
            to: .sRGB,
            alphaType: .premultiplied,
            pixelFormat: .unspecified
        )
        #expect(outputImage.alphaType == .premultiplied)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)

        func linearToSRGB(_ c: Float, alpha: Float) -> Float {
            let v = ((c < 0.0031308) ? (12.92 * c) : (1.055 * pow(c, 1.0 / 2.4) - 0.055))
            return v * 255.0 * alpha // cgImage has premultiplied alpha
        }
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(round(linearToSRGB(c, alpha: 0.5)))
                #expect(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 128)
            }
        }
    }

    @Test func linearToSRGB_inputPremultipliedAlpha() throws {
        let image = MTIImage(
            bitmapData: Data([64, 64, 64, 128]),
            width: 1,
            height: 1,
            bytesPerRow: 4,
            pixelFormat: .bgra8Unorm,
            alphaType: .premultiplied
        )
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(
            image,
            from: .linearSRGB,
            to: .sRGB,
            alphaType: .nonPremultiplied,
            pixelFormat: .unspecified
        )
        #expect(outputImage.alphaType == .nonPremultiplied)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)

        func linearToSRGB(_ c: Float, alpha: Float) -> Float {
            let v = ((c < 0.0031308) ? (12.92 * c) : (1.055 * pow(c, 1.0 / 2.4) - 0.055))
            return v * 255.0 * alpha // cgImage has premultiplied alpha
        }
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                let c: Float = 128.0 / 255.0
                let value = UInt8(round(linearToSRGB(c, alpha: 0.5)))
                #expect(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 128)
            }
        }
    }

    @Test func sRGBToLinear() throws {
        let inputValue: Float = 128.0 / 255.0
        let image = MTIImage(
            color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(
            image,
            from: .sRGB,
            to: .linearSRGB,
            alphaType: .nonPremultiplied,
            pixelFormat: .unspecified
        )
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(round((c <= 0.04045) ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) * 255.0))
                #expect(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }

    @Test func linearToLinear() throws {
        let inputValue: Float = 128.0 / 255.0
        let image = MTIImage(
            color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(
            image,
            from: .linearSRGB,
            to: .linearSRGB,
            alphaType: .nonPremultiplied,
            pixelFormat: .unspecified
        )
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(c * 255.0)
                #expect(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }

    @Test func sRGBToSRGB() throws {
        let inputValue: Float = 128.0 / 255.0
        let image = MTIImage(
            color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(
            image,
            from: .sRGB,
            to: .sRGB,
            alphaType: .nonPremultiplied,
            pixelFormat: .unspecified
        )
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(c * 255.0)
                #expect(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }

    @available(iOS 13.0, tvOS 13.0, *)
    @Test func roundCornerFilter_circular() throws {
        try runRoundCornerTest(size: 32, curve: .circular, allowedDifference: 64)
    }

    @available(iOS 13.0, tvOS 13.0, *)
    @Test func roundCornerFilter_continuous() throws {
        try runRoundCornerTest(size: 32, curve: .continuous, allowedDifference: 64)
    }

    @Test func multilayerCompositing_roundCorner_circular() throws {
        let image = try #require(MTIImage.white.resized(to: CGSize(width: 32, height: 32)))
        let roundCornerFilter = MTIRoundCornerFilter()
        roundCornerFilter.cornerRadius = MTICornerRadius(16)
        roundCornerFilter.cornerCurve = .circular
        roundCornerFilter.inputImage = image
        let roundImage = try #require(roundCornerFilter.outputImage)

        let multilayerCompositingFilter = MultilayerCompositingFilter()
        multilayerCompositingFilter.inputBackgroundImage = MTIImage(
            color: .clear,
            sRGB: false,
            size: CGSize(width: 64, height: 64)
        )
        multilayerCompositingFilter.layers = [MultilayerCompositingFilter.Layer(content: image).frame(
            CGRect(x: 32, y: 32, width: 32, height: 32),
            layoutUnit: .pixel
        ).corner(radius: MTICornerRadius(16), curve: .circular)]
        let compositedImage = try #require(multilayerCompositingFilter.outputImage)

        let context = try makeContext()
        let roundCornerFilterOutput = try context.makeCGImage(from: roundImage)
        let multilayerCompositingFilterOutput = try context
            .makeCGImage(from: #require(compositedImage.cropped(to: CGRect(
                x: 32,
                y: 32,
                width: 32,
                height: 32
            ))))
        #expect(roundCornerFilterOutput.dataProvider?.data == multilayerCompositingFilterOutput.dataProvider?
            .data)
    }

    @Test func multilayerCompositing_roundCorner_continuous() throws {
        let image = try #require(MTIImage.white.resized(to: CGSize(width: 32, height: 32)))
        let roundCornerFilter = MTIRoundCornerFilter()
        roundCornerFilter.cornerRadius = MTICornerRadius(8)
        roundCornerFilter.cornerCurve = .continuous
        roundCornerFilter.inputImage = image
        let roundImage = try #require(roundCornerFilter.outputImage)
        let multilayerCompositingFilter = MultilayerCompositingFilter()
        multilayerCompositingFilter.inputBackgroundImage = MTIImage(
            color: .clear,
            sRGB: false,
            size: CGSize(width: 64, height: 64)
        )
        multilayerCompositingFilter.layers = [MultilayerCompositingFilter.Layer(content: image).frame(
            CGRect(x: 32, y: 32, width: 32, height: 32),
            layoutUnit: .pixel
        ).corner(radius: MTICornerRadius(8), curve: .continuous)]
        let compositedImage = try #require(multilayerCompositingFilter.outputImage)

        let context = try makeContext()
        let roundCornerFilterOutput = try context.makeCGImage(from: roundImage)
        let multilayerCompositingFilterOutput = try context
            .makeCGImage(from: #require(compositedImage.cropped(to: CGRect(
                x: 32,
                y: 32,
                width: 32,
                height: 32
            ))))

        #expect(roundCornerFilterOutput.dataProvider?.data == multilayerCompositingFilterOutput.dataProvider?
            .data)
    }

    @Test func multilayerCompositing_roundCorner_none() throws {
        let image = try #require(MTIImage.white.resized(to: CGSize(width: 32, height: 32)))
        let multilayerCompositingFilter = MultilayerCompositingFilter()
        multilayerCompositingFilter.inputBackgroundImage = MTIImage(
            color: .clear,
            sRGB: false,
            size: CGSize(width: 64, height: 64)
        )
        multilayerCompositingFilter.layers = [MultilayerCompositingFilter.Layer(content: image).frame(
            CGRect(x: 32, y: 32, width: 32, height: 32),
            layoutUnit: .pixel
        ).corner(radius: MTICornerRadius(0), curve: .continuous)]
        let compositedImage = try #require(multilayerCompositingFilter.outputImage)
        let context = try makeContext()
        let roundCornerFilterOutput = try context.makeCGImage(from: image)
        let multilayerCompositingFilterOutput = try context
            .makeCGImage(from: #require(compositedImage.cropped(to: CGRect(
                x: 32,
                y: 32,
                width: 32,
                height: 32
            ))))
        #expect(roundCornerFilterOutput.dataProvider?.data == multilayerCompositingFilterOutput.dataProvider?
            .data)
    }

    @Test func zeroSizeImage_failure() throws {
        let image = MTIImage(color: .white, sRGB: false, size: .zero)
        let context = try makeContext()
        do {
            _ = try context.startTask(toRender: image, completion: nil)
            Issue.record()
        } catch {
            #expect((error as? MTIError)?.code == .invalidTextureDimension)
        }
    }

    @Test func zeroSizeImage_filter_failure() throws {
        let image = MTIImage(color: .white, sRGB: false, size: CGSize(width: 1, height: 1))
        let intermediate = MTIRenderPipelineKernel.passthrough.apply(
            to: [image],
            parameters: [:],
            outputDimensions: MTITextureDimensions(width: 1, height: 0, depth: 1),
            outputPixelFormat: .unspecified
        )
        let output = MTIRenderPipelineKernel.passthrough.apply(
            to: [intermediate],
            parameters: [:],
            outputDimensions: MTITextureDimensions(width: 1, height: 1, depth: 1),
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        do {
            _ = try context.startTask(toRender: output, completion: nil)
            Issue.record()
        } catch {
            #expect((error as? MTIError)?.code == .invalidTextureDimension)
        }
    }

    // The expected values below were captured from the filter's behavior and pin down the
    // spline evaluation, the per-channel curves and the intensity blend.
    private func toneCurveOutput(_ configure: (MTIRGBToneCurveFilter) -> Void) throws -> [UInt8] {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeMonochromeImage([[0, 64, 128, 192, 255]]),
            isOpaque: true
        )
        let filter = MTIRGBToneCurveFilter()
        configure(filter)
        filter.inputImage = image
        var values: [UInt8] = []
        try PixelEnumerator
            .enumeratePixels(in: context.makeCGImage(from: #require(filter.outputImage))) { pixel, _ in
                values.append(pixel.r)
                values.append(pixel.g)
                values.append(pixel.b)
            }
        return values
    }

    /// A curve lifting the midpoint from 0.5 to 0.75.
    private var toneCurveLiftingControlPoints: [MTIVector] {
        [MTIVector(value: CGPoint(x: 0, y: 0)),
         MTIVector(value: CGPoint(x: 0.5, y: 0.75)),
         MTIVector(value: CGPoint(x: 1, y: 1))]
    }

    @Test func rGBToneCurveFilter_compositeCurve() throws {
        let values = try toneCurveOutput { $0.rgbCompositeControlPoints = toneCurveLiftingControlPoints }
        #expect(values == [0, 0, 0,
                           107, 107, 107,
                           191, 191, 191,
                           235, 235, 235,
                           255, 255, 255])
    }

    @Test func rGBToneCurveFilter_perChannelCurves() throws {
        let red = try toneCurveOutput { $0.redControlPoints = toneCurveLiftingControlPoints }
        #expect(red == [0, 0, 0,
                        107, 64, 64,
                        191, 128, 128,
                        235, 192, 192,
                        255, 255, 255])

        let green = try toneCurveOutput { $0.greenControlPoints = toneCurveLiftingControlPoints }
        #expect(green == [0, 0, 0,
                          64, 107, 64,
                          128, 191, 128,
                          192, 235, 192,
                          255, 255, 255])

        let blue = try toneCurveOutput { $0.blueControlPoints = toneCurveLiftingControlPoints }
        #expect(blue == [0, 0, 0,
                         64, 64, 107,
                         128, 128, 191,
                         192, 192, 235,
                         255, 255, 255])
    }

    @Test func rGBToneCurveFilter_intensity() throws {
        let values = try toneCurveOutput {
            $0.rgbCompositeControlPoints = toneCurveLiftingControlPoints
            $0.intensity = 0.5
        }
        #expect(values == [0, 0, 0,
                           86, 86, 86,
                           159, 159, 159,
                           213, 213, 213,
                           255, 255, 255])
    }

    /// A filter with no control points has an identity lookup table and passes the image through.
    @Test func rGBToneCurveFilter_noControlPoints() throws {
        let values = try toneCurveOutput { _ in }
        #expect(values == [0, 0, 0,
                           64, 64, 64,
                           128, 128, 128,
                           192, 192, 192,
                           255, 255, 255])
    }

    /// Control points that do not span the full range are clamped flat outside it.
    @Test func rGBToneCurveFilter_partialRangeControlPoints() throws {
        let values = try toneCurveOutput {
            $0.redControlPoints = [MTIVector(value: CGPoint(x: 0.25, y: 0)),
                                   MTIVector(value: CGPoint(x: 0.75, y: 1))]
        }
        #expect(values == [0, 0, 0,
                           0, 64, 64,
                           128, 128, 128,
                           255, 192, 192,
                           255, 255, 255])
    }

    // The expected values below were captured from the filter's behavior and pin down the tiling,
    // the clip limit and the LUT interpolation.
    private func claheOutput(_ configure: (MTICLAHEFilter) -> Void) throws -> [UInt8] {
        let context = try makeContext()
        let image = try MTIImage(cgImage: ImageGenerator.makeMonochromeImage([
            [10, 40, 70, 100],
            [130, 160, 190, 220],
            [250, 20, 50, 80],
            [110, 140, 170, 200],
        ]), isOpaque: true)
        let filter = MTICLAHEFilter()
        configure(filter)
        filter.inputImage = image
        var values: [UInt8] = []
        try PixelEnumerator
            .enumeratePixels(in: context.makeCGImage(from: #require(filter.outputImage))) { pixel, _ in
                values.append(pixel.r)
            }
        return values
    }

    @Test func cLAHEFilter_defaultConfiguration() throws {
        let values = try claheOutput { _ in }
        #expect(values == [64, 128, 255, 128,
                           0, 128, 0, 128,
                           62, 191, 63, 128,
                           128, 191, 64, 255])
    }

    @Test func cLAHEFilter_clipLimitAndTileGrid() throws {
        let values = try claheOutput {
            $0.clipLimit = 1.0
            $0.tileGridSize = MTICLAHESize(width: 2, height: 2)
        }
        #expect(values == [64, 175, 255, 128,
                           96, 211, 48, 173,
                           79, 203, 56, 189,
                           127, 255, 112, 253])
    }

    @Test func cLAHEFilter_finerTileGrid() throws {
        let values = try claheOutput { $0.tileGridSize = MTICLAHESize(width: 4, height: 4) }
        #expect(values == [255, 253, 255, 255,
                           255, 254, 255, 243,
                           249, 255, 253, 244,
                           251, 255, 255, 246])
    }

    @Test func cropFilter_fractionalAndPixelRegions() throws {
        let image = try MTIImage(
            cgImage: ImageGenerator.makeMonochromeImage([[0, 85, 170, 255]]),
            isOpaque: true
        )
        let context = try makeContext()

        let filter = MTICropFilter()
        filter.inputImage = image

        // The right half of the image, expressed both ways, selects the last two samples.
        for region in [MTICropRegion.fractional(CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
                       MTICropRegion.pixel(CGRect(x: 2, y: 0, width: 2, height: 1))]
        {
            filter.cropRegion = region
            let output = try #require(filter.outputImage)
            #expect(output.size == CGSize(width: 2, height: 1))
            var values: [UInt8] = []
            try PixelEnumerator.enumeratePixels(in: context.makeCGImage(from: output)) { pixel, _ in
                #expect(pixel.r == pixel.g && pixel.g == pixel.b)
                values.append(pixel.r)
            }
            #expect(values == [170, 255])
        }
    }

    @Test func cropFilter_scaleRoundingModes() throws {
        let image = try MTIImage(
            cgImage: ImageGenerator.makeMonochromeImage([[0, 85, 170, 255]]),
            isOpaque: true
        )
        let filter = MTICropFilter()
        filter.inputImage = image
        filter.cropRegion = .pixel(CGRect(x: 0, y: 0, width: 3, height: 2))
        filter.scale = 0.5

        // 3 * 0.5 == 1.5, 2 * 0.5 == 1.0
        filter.roundingMode = .plain
        #expect(try #require(filter.outputImage).size == CGSize(width: 2, height: 1))
        filter.roundingMode = .ceiling
        #expect(try #require(filter.outputImage).size == CGSize(width: 2, height: 1))
        filter.roundingMode = .floor
        #expect(try #require(filter.outputImage).size == CGSize(width: 1, height: 1))
    }

    @Test func cropFilter_fullRegionPassesInputThrough() throws {
        let image = try MTIImage(
            cgImage: ImageGenerator.makeMonochromeImage([[0, 85, 170, 255]]),
            isOpaque: true
        )
        let filter = MTICropFilter()
        filter.inputImage = image
        #expect(filter.outputImage === image)
    }

    @Test func cropFilter_emptyRegionProducesNoImage() throws {
        let image = try MTIImage(
            cgImage: ImageGenerator.makeMonochromeImage([[0, 85, 170, 255]]),
            isOpaque: true
        )
        let filter = MTICropFilter()
        filter.inputImage = image
        filter.cropRegion = .pixel(CGRect(x: 0, y: 0, width: 0, height: 1))
        #expect(filter.outputImage == nil)
    }
}

extension RenderTests {
    @available(iOS 13.0, tvOS 13.0, *)
    private func runRoundCornerTest(size: Int, curve: MTICornerCurve, allowedDifference: Int) throws {
        let objectSize: Int = size
        let cgContext = try #require(CGContext(
            data: nil,
            width: objectSize,
            height: objectSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ))
        cgContext.setFillColor(CGColor.mti_white)
        cgContext.fill(CGRect(x: 0, y: 0, width: objectSize, height: objectSize))
        let whiteImage = try #require(cgContext.makeImage())
        let inputImage = MTIImage(cgImage: whiteImage, isOpaque: true)
        let context = try makeContext()
        for i in 0 ... objectSize / 2 {
            let filter = MTIRoundCornerFilter()
            filter.inputImage = inputImage
            filter.cornerRadius = MTICornerRadius(Float(i))
            filter.cornerCurve = curve
            let output = try #require(filter.outputImage)
            cgContext.clear(CGRect(x: 0, y: 0, width: objectSize, height: objectSize))
            try cgContext.draw(
                context.makeCGImage(from: output),
                in: CGRect(x: 0, y: 0, width: objectSize, height: objectSize)
            )
            let outputCGImage = try #require(cgContext.makeImage())

            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: objectSize, height: objectSize)
            layer.cornerRadius = CGFloat(i)
            switch curve {
            case .circular:
                layer.cornerCurve = .circular
            case .continuous:
                layer.cornerCurve = .continuous
            @unknown default:
                Issue.record()
            }
            layer.backgroundColor = CGColor.mti_white
            cgContext.clear(CGRect(x: 0, y: 0, width: objectSize, height: objectSize))
            layer.render(in: cgContext)
            let outputLayerImage = try #require(cgContext.makeImage())

            #expect(outputCGImage.bytesPerRow == outputLayerImage.bytesPerRow)

            let outputImageData = try [UInt8](UnsafeBufferPointer<UInt8>(
                start: CFDataGetBytePtr(#require(outputCGImage.dataProvider?.data))!,
                count: outputCGImage.bytesPerRow * outputCGImage.height
            ))
            let outputLayerData = try [UInt8](UnsafeBufferPointer<UInt8>(
                start: CFDataGetBytePtr(#require(outputLayerImage.dataProvider?.data))!,
                count: outputLayerImage.bytesPerRow * outputLayerImage.height
            ))
            for (index, value) in outputImageData.enumerated() {
                let diff = abs(Int(value) - Int(outputLayerData[index]))
                #expect(diff < allowedDifference)
            }
        }
    }

    private func fetchFirstPixel(from texture: MTLTexture, context: MTIContext) throws -> [UInt8] {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        #if os(macOS) || targetEnvironment(macCatalyst)
        textureDescriptor.storageMode = .managed
        #endif
        let cpuTexture = try #require(context.device.makeTexture(descriptor: textureDescriptor))
        let commandBuffer = try #require(context.commandQueue.makeCommandBuffer())
        let blitEncoder = try #require(commandBuffer.makeBlitCommandEncoder())
        blitEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: 1, height: 1, depth: 1),
            to: cpuTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        #if os(macOS) || targetEnvironment(macCatalyst)
        blitEncoder.synchronize(resource: cpuTexture)
        #endif
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var pixels = [UInt8](repeating: 0, count: 4)
        pixels.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            cpuTexture.getBytes(
                ptr.baseAddress!,
                bytesPerRow: 4,
                from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(
                    width: 1,
                    height: 1,
                    depth: 1
                )),
                mipmapLevel: 0
            )
        }
        return pixels
    }
}
