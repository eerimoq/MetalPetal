//
//  ImageLoadingTests.swift
//
//
//  Created by YuAo on 2021/2/2.
//

import MetalPetal
import MetalPetalTestHelpers
import Testing
import VideoToolbox

@Suite(.enabled(if: metalDeviceIsAvailable))
struct ImageLoadingTests {
    @Test func cVPixelBufferLoading_cvMetalTextureCache() throws {
        var buffer: CVPixelBuffer?
        let r = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
            &buffer
        )
        guard let pixelBuffer = buffer, r == kCVReturnSuccess else {
            Issue.record("Cannot create pixel buffer.")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let pixels = CVPixelBufferGetBaseAddress(pixelBuffer)?.assumingMemoryBound(to: UInt8.self) {
            pixels.advanced(by: 0).update(repeating: 255, count: 1)
            pixels.advanced(by: 1).update(repeating: 0, count: 1)
            pixels.advanced(by: 2).update(repeating: 0, count: 1)
            pixels.advanced(by: 3).update(repeating: 255, count: 1)
            pixels.advanced(by: 0 + CVPixelBufferGetBytesPerRow(pixelBuffer)).update(repeating: 0, count: 1)
            pixels.advanced(by: 1 + CVPixelBufferGetBytesPerRow(pixelBuffer)).update(repeating: 255, count: 1)
            pixels.advanced(by: 2 + CVPixelBufferGetBytesPerRow(pixelBuffer)).update(repeating: 0, count: 1)
            pixels.advanced(by: 3 + CVPixelBufferGetBytesPerRow(pixelBuffer)).update(repeating: 255, count: 1)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        let image = MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .nonPremultiplied)
        let options = MTIContextOptions()
        options.makeCoreVideoMetalTextureBridge = { try MTICVMetalTextureCache(device: $0) }
        let context = try makeContext(options: options)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 0)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 0)
            }
        }
    }

    @Test func cVPixelBufferLoading_ioSurface() throws {
        var buffer: CVPixelBuffer?
        let r = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
            &buffer
        )
        guard let pixelBuffer = buffer, r == kCVReturnSuccess else {
            Issue.record("Cannot create pixel buffer.")
            return
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let pixels = CVPixelBufferGetBaseAddress(pixelBuffer)?.assumingMemoryBound(to: UInt8.self) {
            pixels.advanced(by: 0).update(repeating: 255, count: 1)
            pixels.advanced(by: 1).update(repeating: 0, count: 1)
            pixels.advanced(by: 2).update(repeating: 0, count: 1)
            pixels.advanced(by: 3).update(repeating: 255, count: 1)
            pixels.advanced(by: 0 + CVPixelBufferGetBytesPerRow(pixelBuffer)).update(repeating: 0, count: 1)
            pixels.advanced(by: 1 + CVPixelBufferGetBytesPerRow(pixelBuffer)).update(repeating: 255, count: 1)
            pixels.advanced(by: 2 + CVPixelBufferGetBytesPerRow(pixelBuffer)).update(repeating: 0, count: 1)
            pixels.advanced(by: 3 + CVPixelBufferGetBytesPerRow(pixelBuffer)).update(repeating: 255, count: 1)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        let image = MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .nonPremultiplied)
        let options = MTIContextOptions()
        options.makeCoreVideoMetalTextureBridge = { MTICVMetalIOSurfaceBridge(device: $0) }
        let context = try makeContext(options: options)
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 0)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 0)
            }
        }
    }

    @Test func bitmapDataLoading() throws {
        let bitmapData: [UInt8] = [
            255, 255, 255, 255,
            255, 255, 0, 255,
        ]
        let image = MTIImage(
            bitmapData: Data(bytes: bitmapData, count: bitmapData.count),
            width: 2,
            height: 1,
            bytesPerRow: 8,
            pixelFormat: .rgba8Unorm,
            alphaType: .alphaIsOne
        )
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
}

@Suite(.enabled(if: metalDeviceIsAvailable))
struct CGImageLoadingTests {
    @Test func cGImageLoading_normal() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeCheckboardImage(),
            options: .default,
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func cGImageLoading_monochrome() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeCheckboardImageWithMonochromeColorSpace(),
            options: .default,
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func cGImageLoading_5bpc() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeCheckboardImageWith5BitPerComponent(),
            options: .default,
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func cGImageLoading_bigEndianAlphaLast() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeR0G128B255CheckboardImageWithBigEndianAlphaLast(),
            options: .default,
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func cGImageLoading_bigEndianAlphaFirst() throws {
        let context = try makeContext()

        let image = try MTIImage(
            cgImage: ImageGenerator.makeR0G128B255CheckboardImageWithBigEndianAlphaFirst(),
            options: .default,
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func cGImageLoading_defaultEndianAlphaFirst() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeR0G128B255CheckboardImageWithDefaultEndianAlphaFirst(),
            options: .default,
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func cGImageLoading_premultiplied() throws {
        let context = try makeContext()
        let cgContext = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        let color: [CGFloat] = [1, 0, 0, 0.5]
        try cgContext?.setFillColor(#require(CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: color
        )))
        cgContext?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let inputCGImage = try #require(cgContext?.makeImage())
        let image = MTIImage(cgImage: inputCGImage, options: .default, isOpaque: false)
        #expect(image.alphaType == .premultiplied)

        let cgImage = try context.makeCGImage(from: image) // output is premultiplied
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, _ in
            #expect(pixel.r == 128 && pixel.g == 0 && pixel.b == 0 && pixel.a == 128)
        }
    }

    @Test func cGImageLoading_semiTransparentPNG() throws {
        let context = try makeContext()
        let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixture")
            .appendingPathComponent("semi-transparent-red.png") as CFURL, nil)
        // `#require` cannot nest the way `XCTUnwrap` could, so unwrap the source first.
        let source = try #require(imageSource)
        let inputCGImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let image = MTIImage(cgImage: inputCGImage, options: .default, isOpaque: false)
        #expect(image.alphaType == .premultiplied)

        let cgImage = try context.makeCGImage(from: image) // output is premultiplied
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, _ in
            #expect(pixel.r == 128 && pixel.g == 0 && pixel.b == 0 && pixel.a == 128)
        }
    }

    @Test func cGImageLoading_sRGB() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeMonochromeImage([[128]]),
            options: MTICGImageLoadingOptions(colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)),
            isOpaque: true
        )
        let linearImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: linearImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                let c = 128.0 / 255.0
                let linearValue =
                    UInt8(round((c <= 0.04045) ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) * 255.0))
                #expect(pixel.r == linearValue && pixel.g == linearValue && pixel.b == linearValue && pixel
                    .a == 255)
            }
        }
        let sRGBImage = try context.makeCGImage(from: image, sRGB: true)
        PixelEnumerator.enumeratePixels(in: sRGBImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 128 && pixel.g == 128 && pixel.b == 128 && pixel.a == 255)
            }
        }
    }

    @Test func uRLImageLoading_orientations() throws {
        let context = try makeContext()
        for orientation in 1 ... 8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixture")
                .appendingPathComponent("f\(orientation).png"),
                options: .default, isOpaque: true)
            guard let inputImage = image else {
                Issue.record()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            #expect(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }

    @Test func uRLImageLoading_grayColorSpace_orientations() throws {
        let context = try makeContext()
        for orientation in 1 ... 8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixture")
                .appendingPathComponent("fgray\(orientation).png"),
                options: .default, isOpaque: true)
            guard let inputImage = image else {
                Issue.record()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            #expect(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }

    @Test func uRLImageLoading_grayColorSpace_orientations_flip() throws {
        let context = try makeContext()
        for orientation in 1 ... 8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixture")
                .appendingPathComponent("fgray\(orientation).png"),
                options: MTICGImageLoadingOptions(colorSpace: nil, flipsVertically: true),
                isOpaque: true)
            guard let inputImage = image else {
                Issue.record()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            #expect(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 255, 255],
                [0, 255, 255],
                [0, 0, 255],
                [0, 0, 0],
            ]))
        }
    }
}

@Suite(.enabled(if: metalDeviceIsAvailable))
struct TextureLoaderImageLoadingTests {
    @Test func testCGImageLoading_normal() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeCheckboardImage(),
            options: [.SRGB: false],
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func testCGImageLoading_monochrome() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeCheckboardImageWithMonochromeColorSpace(),
            options: [.SRGB: false],
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func testCGImageLoading_5bpc() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeCheckboardImageWith5BitPerComponent(),
            options: [.SRGB: false],
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func testCGImageLoading_bigEndianAlphaLast() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeR0G128B255CheckboardImageWithBigEndianAlphaLast(),
            options: [.SRGB: false],
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func testCGImageLoading_bigEndianAlphaFirst() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeR0G128B255CheckboardImageWithBigEndianAlphaFirst(),
            options: [.SRGB: false],
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func testCGImageLoading_defaultEndianAlphaFirst() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeR0G128B255CheckboardImageWithDefaultEndianAlphaFirst(),
            options: [.SRGB: false],
            isOpaque: true
        )
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 0 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0, coordinates.y == 1 {
                #expect(pixel.r == 0 && pixel.g == 128 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1, coordinates.y == 1 {
                #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
    }

    @Test func testCGImageLoading_sRGB() throws {
        let context = try makeContext()
        let image = try MTIImage(
            cgImage: ImageGenerator.makeMonochromeImage([[128]]),
            options: [.SRGB: true],
            isOpaque: true
        )
        let linearImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: linearImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                let c = 128.0 / 255.0
                let linearValue =
                    UInt8(round((c <= 0.04045) ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) * 255.0))
                #expect(pixel.r == linearValue && pixel.g == linearValue && pixel.b == linearValue && pixel
                    .a == 255)
            }
        }
        let sRGBImage = try context.makeCGImage(from: image, sRGB: true)
        PixelEnumerator.enumeratePixels(in: sRGBImage) { pixel, coordinates in
            if coordinates.x == 0, coordinates.y == 0 {
                #expect(pixel.r == 128 && pixel.g == 128 && pixel.b == 128 && pixel.a == 255)
            }
        }
    }

    @Test func testURLImageLoading_orientations() throws {
        let context = try makeContext()
        for orientation in 1 ... 8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixture")
                .appendingPathComponent("f\(orientation).png"),
                options: [.SRGB: false],
                alphaType: .alphaIsOne)
            guard let inputImage = image else {
                Issue.record()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            #expect(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }

    @Test func testURLImageLoading_grayColorSpace_orientations() throws {
        let context = try makeContext()
        for orientation in 1 ... 8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixture")
                .appendingPathComponent("fgray\(orientation).png"),
                options: [.SRGB: false],
                alphaType: .alphaIsOne)
            guard let inputImage = image else {
                Issue.record()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            #expect(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }

    @Test func testURLImageLoading_grayColorSpace_orientations_flip() throws {
        let context = try makeContext()
        for orientation in 1 ... 8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixture")
                .appendingPathComponent("fgray\(orientation).png"),
                options: [.SRGB: false, .origin: MTKTextureLoader.Origin.flippedVertically],
                alphaType: .alphaIsOne)
            guard let inputImage = image else {
                Issue.record()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            #expect(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 255, 255],
                [0, 255, 255],
                [0, 0, 255],
                [0, 0, 0],
            ]))
        }
    }

    @Test func uRLImageLoading_grayColorSpace_mtkfallback_orientations() throws {
        let context = try makeContext()
        for orientation in 1 ... 8 {
            let image = MTIImage(contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Fixture")
                .appendingPathComponent("fgray\(orientation).png"),
                options: [.SRGB: false, .generateMipmaps: true],
                alphaType: .alphaIsOne)
            guard let inputImage = image else {
                Issue.record()
                return
            }
            let cgImage = try context.makeCGImage(from: inputImage)
            #expect(PixelEnumerator.monochromeImageEqual(image: cgImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }

    @Test func uRLImageLoading_grayColorSpace_mtkfallback_mipmap() throws {
        let context = try makeContext()
        let url = URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixture")
            .appendingPathComponent("fgray1.png")
        let textureLoader = MTIDefaultTextureLoader(device: context.device)
        let texture = try textureLoader.newTexture(
            withContentsOf: url,
            options: [.SRGB: false, .generateMipmaps: true]
        )
        #expect(texture.mipmapLevelCount > 1)
    }
}
