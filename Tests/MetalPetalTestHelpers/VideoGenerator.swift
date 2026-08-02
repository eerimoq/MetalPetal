//
//  VideoGenerator.swift
//  MetalPetal
//
//  MTIVideoComposition had no tests at all, because the test bundle ships only still images and there
//  was no way to get an AVAsset. This writes a short solid-colour movie to a temporary file so the video
//  composition path can be exercised.
//

import AVFoundation
import CoreVideo
import Foundation

public enum VideoGenerator {
    public enum Error: Swift.Error {
        case failedToCreatePixelBuffer
        case writingFailed(String)
    }

    /// Writes a movie of `frameCount` solid-colour frames at 30fps and returns its URL.
    ///
    /// The caller owns the file and should delete it when done.
    public static func makeTestVideo(
        width: Int = 64,
        height: Int = 48,
        frameCount: Int = 10,
        color: (r: UInt8, g: UInt8, b: UInt8) = (0, 0, 255)
    ) async throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MetalPetalTestVideo-\(UUID().uuidString)")
            .appendingPathExtension("mov")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw Error.writingFailed(writer.error?.localizedDescription ?? "startWriting failed")
        }
        writer.startSession(atSourceTime: .zero)

        let timescale: CMTimeScale = 30
        for frame in 0 ..< frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            let buffer = try makePixelBuffer(width: width, height: height, color: color)
            adaptor.append(
                buffer,
                withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: timescale)
            )
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status == .failed {
            throw Error.writingFailed(writer.error?.localizedDescription ?? "finishWriting failed")
        }
        return url
    }

    private static func makePixelBuffer(
        width: Int,
        height: Int,
        color: (r: UInt8, g: UInt8, b: UInt8)
    ) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
            &buffer
        )
        guard let pixelBuffer = buffer, status == kCVReturnSuccess else {
            throw Error.failedToCreatePixelBuffer
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        }
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer)?.assumingMemoryBound(to: UInt8.self) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let pixel = base.advanced(by: y * bytesPerRow + x * 4)
                    pixel[0] = color.b
                    pixel[1] = color.g
                    pixel[2] = color.r
                    pixel[3] = 255
                }
            }
        }
        return pixelBuffer
    }
}
