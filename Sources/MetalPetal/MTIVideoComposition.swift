//
//  MTIVideoComposition.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/12/19.
//

import AVFoundation
import Foundation
import os

public extension MTIImage {
    func applyingAssetTrackTransform(_ transform: CGAffineTransform) -> MTIImage {
        let transformFilter = MTITransformFilter()
        transformFilter.inputImage = self
        var transform = transform
        transform.tx = 0
        transform.ty = 0
        transformFilter.transform = CATransform3DMakeAffineTransform(transform.inverted())
        transformFilter.viewport = transformFilter.minimumEnclosingViewport
        return transformFilter.outputImage!
    }
}

public protocol MTIVideoCompositionRequest {
    func sourceFrame(byTrackID trackID: CMPersistentTrackID) -> CVPixelBuffer?
    var renderContext: AVVideoCompositionRenderContext { get }
    var compositionTime: CMTime { get }
    /// Whether the track transform is applied to the source frame.
    var isTrackTransformApplied: Bool { get }
}

public protocol MTIMutableVideoCompositionRequest: MTIVideoCompositionRequest {
    func finish(_ result: Result<CVPixelBuffer, Error>)
}

public protocol MTITrackedVideoCompositionRequest: MTIVideoCompositionRequest {
    /// Whether the request is cancelled. The implementation must be thread-safe.
    var isCancelled: Bool { get }
}

extension AVAsynchronousVideoCompositionRequest: MTIMutableVideoCompositionRequest {
    public var isTrackTransformApplied: Bool {
        false
    }

    public func finish(_ result: Result<CVPixelBuffer, Error>) {
        switch result {
        case let .failure(error):
            finish(with: error)
        case let .success(pixelBuffer):
            finish(withComposedVideoFrame: pixelBuffer)
        }
    }
}

public class MTIAsyncVideoCompositionRequestHandler {
    public enum Error: Swift.Error {
        case cannotGenerateOutputPixelBuffer
    }

    public struct Request {
        /// The track's preferred transform is applied.
        public let sourceImages: [CMPersistentTrackID: MTIImage]
        public let compositionTime: CMTime
        public let renderSize: CGSize

        public var anySourceImage: MTIImage? {
            sourceImages.first?.value
        }
    }

    struct Track {
        let id: CMPersistentTrackID
        let preferredTransform: CGAffineTransform

        init(id: CMPersistentTrackID, preferredTransform: CGAffineTransform) {
            self.id = id
            self.preferredTransform = preferredTransform
        }

        init(track: AVAssetTrack) async throws {
            id = track.trackID
            preferredTransform = try await track.load(.preferredTransform)
        }
    }

    private let tracks: [Track]
    private let context: MTIContext
    private let filter: (Request) throws -> MTIImage
    private let queue: DispatchQueue?

    /// Initialize a new `MTIAsyncVideoCompositionRequestHandler` object that can handle
    /// `MTIMutableVideoCompositionRequest` on the specified `queue` using `filter`.
    /// If the `queue` is nil, the `filter` block runs directly on the queue where `handle(request:)` is
    /// called.
    public convenience init(
        context: MTIContext,
        tracks: [AVAssetTrack],
        on queue: DispatchQueue?,
        filter: @escaping (Request) throws -> MTIImage
    ) async throws {
        var loaded: [Track] = []
        loaded.reserveCapacity(tracks.count)
        for track in tracks {
            try await loaded.append(Track(track: track))
        }
        self.init(context: context, tracks: loaded, on: queue, filter: filter)
    }

    /// For callers that have already loaded the track properties, so they are not fetched twice.
    init(
        context: MTIContext,
        tracks: [Track],
        on queue: DispatchQueue?,
        filter: @escaping (Request) throws -> MTIImage
    ) {
        self.tracks = tracks
        self.context = context
        self.filter = filter
        self.queue = queue
    }

    private static func makeTransformedSourceImage(
        from request: MTIMutableVideoCompositionRequest,
        track: Track
    ) -> MTIImage? {
        guard let pixelBuffer = request.sourceFrame(byTrackID: track.id) else {
            return nil
        }
        let image = MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .alphaIsOne)
        if request.isTrackTransformApplied || track.preferredTransform.isIdentity {
            return image
        }
        var trackTransform = track.preferredTransform
        trackTransform.tx = 0
        trackTransform.ty = 0
        let transform = CATransform3DMakeAffineTransform(trackTransform.inverted())
        return MTITransformFilterApplyTransformToImage(
            image,
            transform,
            0,
            1,
            MTITransformFilter.minimumEnclosingViewport(for: image, transform: transform, fieldOfView: 0),
            .unspecified
        )
    }

    private func enqueue(_ operation: @escaping () -> Void) {
        if let queue {
            queue.async(execute: operation)
        } else {
            operation()
        }
    }

    public func handle(request: MTIMutableVideoCompositionRequest) {
        if (request as? MTITrackedVideoCompositionRequest)?.isCancelled == true {
            return
        }
        let sourceFrames = tracks.reduce(into: [CMPersistentTrackID: MTIImage]()) { frames, track in
            if let image = MTIAsyncVideoCompositionRequestHandler.makeTransformedSourceImage(
                from: request,
                track: track
            ) {
                frames[track.id] = image
            }
        }
        guard let pixelBuffer = request.renderContext.newPixelBuffer() else {
            enqueue { request.finish(.failure(Error.cannotGenerateOutputPixelBuffer)) }
            return
        }
        enqueue {
            autoreleasepool {
                do {
                    if (request as? MTITrackedVideoCompositionRequest)?.isCancelled == true {
                        return
                    }
                    let mtiRequest = Request(
                        sourceImages: sourceFrames,
                        compositionTime: request.compositionTime,
                        renderSize: request.renderContext.size
                    )
                    let image = try self.filter(mtiRequest)
                    if (request as? MTITrackedVideoCompositionRequest)?.isCancelled == true {
                        return
                    }
                    try self.context.render(image, to: pixelBuffer)
                    request.finish(.success(pixelBuffer))
                } catch {
                    request.finish(.failure(error))
                }
            }
        }
    }
}

public class MTIVideoComposition {
    public enum Error: Swift.Error {
        case unsupportedInstruction
    }

    private class Compositor: NSObject, AVVideoCompositing {
        class VideoCompositionRequest: Hashable, MTIMutableVideoCompositionRequest,
            MTITrackedVideoCompositionRequest
        {
            private let internalRequest: AVAsynchronousVideoCompositionRequest
            private var completionHandler: (() -> Void)?
            private var _isCancelled: Bool = false
            private let stateLock = OSAllocatedUnfairLock()

            func hash(into hasher: inout Hasher) {
                hasher.combine(internalRequest)
            }

            static func == (lhs: VideoCompositionRequest, rhs: VideoCompositionRequest) -> Bool {
                lhs.internalRequest === rhs.internalRequest
            }

            fileprivate init(request: AVAsynchronousVideoCompositionRequest) {
                internalRequest = request
            }

            fileprivate func onCompletion(_ completion: @escaping () -> Void) {
                completionHandler = completion
            }

            func sourceFrame(byTrackID trackID: CMPersistentTrackID) -> CVPixelBuffer? {
                internalRequest.sourceFrame(byTrackID: trackID)
            }

            var renderContext: AVVideoCompositionRenderContext {
                internalRequest.renderContext
            }

            var compositionTime: CMTime {
                internalRequest.compositionTime
            }

            var isTrackTransformApplied: Bool {
                false
            }

            func finish(_ result: Result<CVPixelBuffer, Swift.Error>) {
                stateLock.lock()
                if !_isCancelled {
                    internalRequest.finish(result)
                    let completion = completionHandler
                    completionHandler = nil
                    stateLock.unlock()
                    completion?()
                } else {
                    stateLock.unlock()
                }
            }

            fileprivate func cancel() {
                stateLock.lock()
                defer {
                    stateLock.unlock()
                }
                internalRequest.finishCancelledRequest()
                _isCancelled = true
                completionHandler = nil
            }

            var isCancelled: Bool {
                stateLock.lock()
                defer {
                    stateLock.unlock()
                }
                return _isCancelled
            }
        }

        class Instruction: NSObject, AVVideoCompositionInstructionProtocol {
            typealias Handler = (_ request: VideoCompositionRequest) -> Void
            let timeRange: CMTimeRange
            let enablePostProcessing: Bool = false
            let containsTweening: Bool = true
            nonisolated(unsafe) let requiredSourceTrackIDs: [NSValue]? = nil
            let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
            let handler: Handler

            init(handler: @escaping Handler, timeRange: CMTimeRange) {
                self.handler = handler
                self.timeRange = timeRange
            }
        }

        let sourcePixelBufferAttributes: [String: any Sendable]? = [
            kCVPixelBufferPixelFormatTypeKey as String: [
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelFormatType_32BGRA,
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            ],
        ]

        let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

        private var pendingRequests: Set<VideoCompositionRequest> = []
        private let pendingRequestsLock = OSAllocatedUnfairLock()

        func renderContextChanged(_: AVVideoCompositionRenderContext) {}

        func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
            guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? Instruction
            else {
                asyncVideoCompositionRequest.finish(with: Error.unsupportedInstruction)
                return
            }
            let request = VideoCompositionRequest(request: asyncVideoCompositionRequest)
            request.onCompletion { [unowned request, weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.pendingRequestsLock.lock()
                strongSelf.pendingRequests.remove(request)
                strongSelf.pendingRequestsLock.unlock()
            }
            pendingRequestsLock.lock()
            pendingRequests.insert(request)
            pendingRequestsLock.unlock()

            instruction.handler(request)
        }

        func cancelAllPendingVideoCompositionRequests() {
            pendingRequestsLock.lock()
            for request in pendingRequests {
                request.cancel()
            }
            pendingRequests = []
            pendingRequestsLock.unlock()
        }
    }

    public let asset: AVAsset

    public var sourceTrackIDForFrameTiming: CMPersistentTrackID {
        get { videoComposition.sourceTrackIDForFrameTiming }
        set { videoComposition.sourceTrackIDForFrameTiming = newValue }
    }

    public var frameDuration: CMTime {
        get { videoComposition.frameDuration }
        set { videoComposition.frameDuration = newValue }
    }

    public var renderSize: CGSize {
        get { videoComposition.renderSize }
        set { videoComposition.renderSize = newValue }
    }

    @available(iOS 11.0, macOS 10.14, *)
    public var renderScale: Float {
        get { videoComposition.renderScale }
        set { videoComposition.renderScale = newValue }
    }

    public var colorPrimaries: String? {
        get { videoComposition.colorPrimaries }
        set { videoComposition.colorPrimaries = newValue }
    }

    public var colorYCbCrMatrix: String? {
        get { videoComposition.colorYCbCrMatrix }
        set { videoComposition.colorYCbCrMatrix = newValue }
    }

    public var colorTransferFunction: String? {
        get { videoComposition.colorTransferFunction }
        set { videoComposition.colorTransferFunction = newValue }
    }

    private let videoComposition: AVMutableVideoComposition

    public func makeAVVideoComposition() -> AVVideoComposition {
        videoComposition.copy() as! AVVideoComposition
    }

    /// Creates a new instance of `MTIVideoComposition` with values and instructions suitable for presenting
    /// and processing the video tracks of the specified asset according to its temporal and geometric
    /// properties and those of its tracks.
    ///
    /// For best performance, ensure that the duration and tracks properties of the asset are already loaded
    /// before invoking this method.
    ///
    /// The created `MTIVideoComposition` will have the following values for its properties:
    /// - If the asset has exactly one video track, the original timing of the source video track will be
    /// used. If the asset has more than one video track, and the nominal frame rate of any of video tracks is
    /// known, the reciprocal of the greatest known nominalFrameRate will be used as the value of
    /// frameDuration. Otherwise, a default framerate of 30fps is used.
    /// - If the specified asset is an instance of AVComposition, the renderSize will be set to the
    /// naturalSize of the AVComposition; otherwise the renderSize will be set to a value that encompasses all
    /// of the asset's video tracks.
    /// - A renderScale of 1.0.
    public init(
        asset inputAsset: AVAsset,
        context: MTIContext,
        queue: DispatchQueue?,
        filter: @escaping (MTIAsyncVideoCompositionRequestHandler.Request) throws -> MTIImage
    ) async throws {
        // A local, so the concurrent loads below do not capture `self` mid-initialization.
        let asset = inputAsset.copy() as! AVAsset
        self.asset = asset

        // Both reads walk the asset's tracks, so start them together rather than one after the other.
        async let loadedComposition = AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
        async let loadedTracks = asset.loadTracks(withMediaType: .video)
        let videoTracks = try await loadedTracks
        videoComposition = try await loadedComposition

        // Each track's properties are loaded once here and handed to the request handler, which would
        // otherwise load `preferredTransform` for every track a second time.
        let tracks = try await withThrowingTaskGroup(
            of: (offset: Int, track: MTIAsyncVideoCompositionRequestHandler.Track, size: CGSize).self
        ) { group in
            for (offset, videoTrack) in videoTracks.enumerated() {
                group.addTask {
                    let (naturalSize, preferredTransform) = try await videoTrack
                        .load(.naturalSize, .preferredTransform)
                    return (
                        offset,
                        .init(id: videoTrack.trackID, preferredTransform: preferredTransform),
                        naturalSize.applying(preferredTransform)
                    )
                }
            }
            // The handler indexes tracks positionally, so restore the source order.
            return try await group.reduce(into: []) { $0.append($1) }.sorted { $0.offset < $1.offset }
        }

        /// AVMutableVideoComposition's renderSize property is buggy with some assets. Calculate the
        /// renderSize here based on the documentation of `AVMutableVideoComposition(propertiesOf:)`
        if let composition = asset as? AVComposition {
            videoComposition.renderSize = composition.naturalSize
        } else {
            videoComposition.renderSize = tracks.reduce(into: CGSize.zero) { renderSize, track in
                renderSize.width = max(renderSize.width, abs(track.size.width))
                renderSize.height = max(renderSize.height, abs(track.size.height))
            }
        }

        videoComposition.customVideoCompositorClass = Compositor.self
        let handler = MTIAsyncVideoCompositionRequestHandler(
            context: context,
            tracks: tracks.map(\.track),
            on: queue,
            filter: filter
        )
        videoComposition.instructions = [Compositor.Instruction(
            handler: handler.handle(request:),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: CMTimeValue.max, timescale: 48000))
        )]
    }
}
