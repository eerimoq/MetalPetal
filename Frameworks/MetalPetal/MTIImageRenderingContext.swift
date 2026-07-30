//
//  MTIImageRenderingContext.swift
//  MetalPetal
//

import Foundation
import Metal
import MetalPetalObjectiveC.Extension

public let MTIContextImagePersistentResolutionHolderTableName = "MTIContextImagePersistentResolutionHolderTable"

private let MTIContextImagePersistentResolutionHolderTable =
    MTIContextImageAssociatedValueTableName(rawValue: MTIContextImagePersistentResolutionHolderTableName)

public protocol MTIImagePromiseResolution: AnyObject {
    var texture: MTLTexture { get }
    func markAsConsumed(by consumer: AnyObject)
}

private final class MTIImageRenderingDependencyGraph {
    // promise identity -> its dependents (the promises that depend on it).
    private var table: [ObjectIdentifier: [MTIImagePromise]] = [:]

    func addDependencies(for image: MTIImage) {
        for dependency in image.promise.dependencies {
            let promise = dependency.promise
            let key = ObjectIdentifier(promise)
            if table[key] == nil {
                // Using array here, because a promise may have two or more identical dependents.
                table[key] = [image.promise]
                addDependencies(for: dependency)
            } else {
                table[key]?.append(image.promise)
            }
        }
    }

    func dependentCount(for promise: MTIImagePromise) -> Int {
        guard let dependents = table[ObjectIdentifier(promise)] else {
            assertionFailure("Promise: \(promise) is not in this dependency graph.")
            return 0
        }
        return dependents.count
    }

    func removeDependent(_ dependent: MTIImagePromise, for promise: MTIImagePromise) {
        let key = ObjectIdentifier(promise)
        guard var dependents = table[key] else {
            assertionFailure("Dependents not found.")
            return
        }
        guard let index = dependents.firstIndex(where: { $0 === dependent }) else {
            assertionFailure("Dependent not found in promise's dependents array.")
            return
        }
        dependents.remove(at: index)
        table[key] = dependents
    }
}

private final class MTITransientImagePromiseResolution: NSObject, MTIImagePromiseResolution {
    let texture: MTLTexture
    private var invalidationHandler: ((AnyObject) -> Void)?

    init(texture: MTLTexture, invalidationHandler: @escaping (AnyObject) -> Void) {
        self.texture = texture
        self.invalidationHandler = invalidationHandler
        super.init()
    }

    func markAsConsumed(by consumer: AnyObject) {
        invalidationHandler?(consumer)
        invalidationHandler = nil
    }

    deinit {
        assert(invalidationHandler == nil)
    }
}

private final class MTIPersistImageResolutionHolder: NSObject {
    @objc let renderTarget: MTIImagePromiseRenderTarget

    init(renderTarget: MTIImagePromiseRenderTarget) {
        self.renderTarget = renderTarget
        _ = renderTarget.retainTexture()
        super.init()
    }

    deinit {
        renderTarget.releaseTexture()
    }
}

public final class MTIImageRenderingContext: NSObject {
    public let context: MTIContext

    public let commandBuffer: MTLCommandBuffer

    private var resolvedPromises: [ObjectIdentifier: (
        promise: MTIImagePromise,
        renderTarget: MTIImagePromiseRenderTarget
    )] = [:]

    private var dependencyGraph: MTIImageRenderingDependencyGraph?
    private var currentDependencyResolutionMap: [ObjectIdentifier: MTLTexture] = [:]
    private var currentDependencySamplerStateMap: [ObjectIdentifier: MTLSamplerState] = [:]
    private weak var currentResolvingPromise: AnyObject?

    public init(context: MTIContext) {
        self.context = context
        commandBuffer = context.commandQueue.makeCommandBuffer()!
        super.init()
    }

    deinit {
        if commandBuffer.status == .notEnqueued || commandBuffer.status == .enqueued {
            commandBuffer.commit()
        }
    }

    public func resolvedTexture(for image: MTIImage) -> MTLTexture {
        let promise = currentResolvingPromise
        assert(promise != nil)
        guard let result = currentDependencyResolutionMap[ObjectIdentifier(image)], promise != nil else {
            NSException(
                name: .internalInconsistencyException,
                reason: """
                Do not query resolved texture for image which is not the current \
                resolving promise's dependency. (Image: \(image))
                """,
                userInfo: nil
            ).raise()
            fatalError()
        }
        return result
    }

    public func resolvedSamplerState(for image: MTIImage) -> MTLSamplerState {
        let promise = currentResolvingPromise
        assert(promise != nil)
        guard let result = currentDependencySamplerStateMap[ObjectIdentifier(image)], promise != nil else {
            NSException(
                name: .internalInconsistencyException,
                reason: """
                Do not query resolved sampler state for image which is not the \
                current resolving promise's dependency. (Image: \(image))
                """,
                userInfo: nil
            ).raise()
            fatalError()
        }
        return result
    }

    public func resolution(for image: MTIImage) throws -> MTIImagePromiseResolution {
        var isRootImage = false
        var promise: MTIImagePromise = image.promise
        if dependencyGraph == nil {
            // If we don't have the dependency graph, we're processing the root image.
            isRootImage = true
            let graph = MTIImageRenderingDependencyGraph()
            dependencyGraph = graph
            if context.isRenderGraphOptimizationEnabled {
                let optimizedPromise = MTIRenderGraphOptimizer.promiseByOptimizingRenderGraph(of: promise)
                promise = optimizedPromise
                let optimizedImage = MTIImage(
                    promise: optimizedPromise,
                    samplerDescriptor: image.samplerDescriptor,
                    cachePolicy: image.cachePolicy
                )
                graph.addDependencies(for: optimizedImage)
            } else {
                graph.addDependencies(for: image)
            }
        }
        let promiseKey = ObjectIdentifier(promise)
        var renderTarget: MTIImagePromiseRenderTarget
        if let existing = resolvedPromises[promiseKey] {
            renderTarget = existing.renderTarget
            // Promise resolved.
            assert(renderTarget.texture != nil)
        } else {
            // Maybe the context has a resolved promise. (The image has a persistent cache policy)
            let cachedRenderTarget = context.renderTarget(for: promise)
            if let cachedRenderTarget, cachedRenderTarget.retainTexture() {
                // Got the render target from the context, we need to retain the texture here. [A]
                renderTarget = cachedRenderTarget
                assert(renderTarget.texture != nil)
            } else {
                // All caches miss. Resolve promise.
                if promise.dimensions.width > 0, promise.dimensions.height > 0, promise.dimensions.depth > 0 {
                    var inputResolutions: [MTIImagePromiseResolution] = []
                    var textureMap: [ObjectIdentifier: MTLTexture] = [:]
                    var samplerStateMap: [ObjectIdentifier: MTLSamplerState] = [:]
                    do {
                        for dependencyImage in promise.dependencies {
                            let resolution = try resolution(for: dependencyImage)
                            inputResolutions.append(resolution)
                            textureMap[ObjectIdentifier(dependencyImage)] = resolution.texture

                            let samplerState = try context
                                .samplerState(with: dependencyImage.samplerDescriptor)
                            samplerStateMap[ObjectIdentifier(dependencyImage)] = samplerState
                        }
                        currentDependencyResolutionMap = textureMap
                        currentDependencySamplerStateMap = samplerStateMap
                        currentResolvingPromise = promise
                        let resolvedTarget = try promise.resolve(with: self)
                        // New render target got from promise resolving, texture ref-count is 1. [B]
                        currentResolvingPromise = nil
                        for resolution in inputResolutions {
                            resolution.markAsConsumed(by: promise)
                        }
                        renderTarget = resolvedTarget
                    } catch {
                        currentResolvingPromise = nil
                        for resolution in inputResolutions {
                            resolution.markAsConsumed(by: promise)
                        }
                        if isRootImage {
                            // Clean up
                            for (_, entry) in resolvedPromises
                                where dependencyGraph!.dependentCount(for: entry.promise) != 0
                            {
                                entry.renderTarget.releaseTexture()
                            }
                        }
                        throw error
                    }
                } else {
                    throw _MTIErrorCreate(.invalidTextureDimension, "MTIErrorInvalidTextureDimension", nil)
                }
                // Make sure the render target is valid.
                assert(renderTarget.texture != nil)
                if image.cachePolicy == .persistent {
                    // Share the render result with the context.
                    context.setRenderTarget(renderTarget, for: promise)
                }
            }
            resolvedPromises[promiseKey] = (promise, renderTarget)
        }
        if image.cachePolicy == .persistent {
            var persistResolution = context.value(
                forImage: image,
                in: MTIContextImagePersistentResolutionHolderTable
            ) as? MTIPersistImageResolutionHolder
            if persistResolution == nil {
                // Create a holder for the render target. Retain the texture. Preventing the texture from
                // being reused at location [C]
                persistResolution = MTIPersistImageResolutionHolder(renderTarget: renderTarget)
                context.setValue(
                    persistResolution,
                    forImage: image,
                    in: MTIContextImagePersistentResolutionHolderTable
                )
            }
        }
        if isRootImage {
            return MTITransientImagePromiseResolution(
                texture: renderTarget.texture!,
                invalidationHandler: { _ in
                    // Root render result is consumed, releasing the texture.
                    renderTarget.releaseTexture()
                }
            )
        } else {
            let capturedPromise = promise
            return MTITransientImagePromiseResolution(
                texture: renderTarget.texture!,
                invalidationHandler: { [weak self] consumer in
                    guard let self, let graph = dependencyGraph else { return }
                    graph.removeDependent(consumer as! MTIImagePromise, for: capturedPromise)
                    if graph.dependentCount(for: capturedPromise) == 0 {
                        // Nothing depends on this render result, releasing the texture. [C]
                        renderTarget.releaseTexture()
                    }
                }
            )
        }
    }
}

private final class MTIImageBufferPromise: NSObject, MTIImagePromise {
    @objc private let resolution: MTIPersistImageResolutionHolder
    private weak var context: MTIContext?
    let dimensions: MTITextureDimensions
    let alphaType: MTIAlphaType

    fileprivate init(
        persistImageResolutionHolder holder: MTIPersistImageResolutionHolder,
        dimensions: MTITextureDimensions,
        alphaType: MTIAlphaType,
        context: MTIContext
    ) {
        self.dimensions = dimensions
        self.alphaType = alphaType
        resolution = holder
        self.context = context
        super.init()
    }

    func copy(with _: NSZone? = nil) -> Any {
        self
    }

    var dependencies: [MTIImage] {
        []
    }

    func resolve(with renderingContext: MTIImageRenderingContext) throws -> MTIImagePromiseRenderTarget {
        assert(renderingContext.context === context)
        if renderingContext.context !== context {
            throw _MTIErrorCreate(.crossContextRendering, "MTIErrorCrossContextRendering", nil)
        }
        _ = resolution.renderTarget.retainTexture()
        return resolution.renderTarget
    }

    func updatingDependencies(_ dependencies: [MTIImage]) -> Self {
        assert(dependencies.count == 0)
        return self
    }

    var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: resolution)
    }
}

public extension MTIContext {
    func renderedBuffer(for targetImage: MTIImage) -> MTIImage? {
        assert(targetImage.cachePolicy == .persistent)
        guard let persistResolution = value(
            forImage: targetImage,
            in: MTIContextImagePersistentResolutionHolderTable
        ) as? MTIPersistImageResolutionHolder else {
            return nil
        }
        return MTIImage(
            promise: MTIImageBufferPromise(persistImageResolutionHolder: persistResolution,
                                           dimensions: targetImage.dimensions,
                                           alphaType: targetImage.alphaType, context: self),
            samplerDescriptor: targetImage.samplerDescriptor,
            cachePolicy: .persistent
        )
    }
}
