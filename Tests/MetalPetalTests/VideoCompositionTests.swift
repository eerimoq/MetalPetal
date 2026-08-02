//
//  VideoCompositionTests.swift
//  MetalPetal
//
//  MTIVideoComposition had no coverage at all -- its only consumer was the example app. That mattered
//  because it is the one type still reading AVAsset properties synchronously, and migrating those to the
//  async `load` APIs is not something worth attempting without a test that the composition still
//  produces the right render size and still runs the filter over real frames.
//

import AVFoundation
@testable import MetalPetal
import MetalPetalTestHelpers
import Testing

@Suite(.enabled(if: metalDeviceIsAvailable), .serialized)
struct VideoCompositionTests {
    /// Builds a composition over a generated movie and reads back the first composed frame.
    private func composedFirstFrame(
        width: Int = 64,
        height: Int = 48,
        filter: @escaping (MTIAsyncVideoCompositionRequestHandler.Request) throws -> MTIImage
    ) async throws -> (composition: MTIVideoComposition, pixel: PixelEnumerator.Pixel) {
        let url = try await VideoGenerator.makeTestVideo(width: width, height: height, frameCount: 4)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        let asset = AVURLAsset(url: url)
        let context = try makeContext()
        let composition = try await MTIVideoComposition(
            asset: asset,
            context: context,
            queue: nil,
            filter: filter
        )
        let reader = try AVAssetReader(asset: asset)
        let output = try await AVAssetReaderVideoCompositionOutput(
            videoTracks: asset.loadTracks(withMediaType: .video),
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        output.videoComposition = composition.makeAVVideoComposition()
        reader.add(output)
        #expect(reader.startReading())
        let sample = try #require(output.copyNextSampleBuffer(), "no composed frame produced")
        let pixelBuffer = try #require(CMSampleBufferGetImageBuffer(sample))
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        let base = try #require(CVPixelBufferGetBaseAddress(pixelBuffer)?.assumingMemoryBound(to: UInt8.self))
        return (composition, PixelEnumerator.Pixel(b: base[0], g: base[1], r: base[2], a: base[3]))
    }

    /// One passthrough run covers both halves of the contract, so the movie is generated, encoded and
    /// composed once rather than twice: the render size comes from the source track's natural size and
    /// preferred transform -- the properties the async load migration touched -- and the composed pixel
    /// proves frames actually flow through the compositor rather than the reader handing back an
    /// untouched or empty buffer.
    @Test func passthroughCompositionPreservesSizeAndFrames() async throws {
        let (composition, pixel) = try await composedFirstFrame { request in
            try #require(request.anySourceImage)
        }
        #expect(composition.renderSize == CGSize(width: 64, height: 48))
        // The generator writes pure blue; h264 is lossy, so allow a little slack.
        #expect(pixel.b > 200)
        #expect(pixel.r < 60)
        #expect(pixel.g < 60)
    }

    /// And a filter that actually changes the image must show up in the output.
    @Test func filterIsAppliedToComposedFrames() async throws {
        let (_, pixel) = try await composedFirstFrame { request in
            let source = try #require(request.anySourceImage)
            let invert = MTIColorInvertFilter()
            invert.inputImage = source
            return try #require(invert.outputImage)
        }
        // Inverted blue is yellow.
        #expect(pixel.b < 60)
        #expect(pixel.r > 200)
        #expect(pixel.g > 200)
    }
}
