//
//  MTIContext.swift
//  MetalPetal
//
//  Created by YuAo on 25/06/2017.
//

import CoreImage
import CoreVideo
import Foundation
import Metal
import MetalKit
import MetalPerformanceShaders
import os

public let MTIContextDefaultLabel = "MetalPetal"

public struct MTIContextPromiseAssociatedValueTableName: RawRepresentable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct MTIContextImageAssociatedValueTableName: RawRepresentable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public func MTIDefaultLibraryURLForBundle(_ bundle: Bundle) -> URL? {
    bundle.url(forResource: "default", withExtension: "metallib")
}

private func MTIMPSSupportsMTLDevice(_ device: MTLDevice) -> Bool {
    MPSSupportsMTLDevice(device)
}

/// Options for creating a MTIContext.
public final class MTIContextOptions {
    public var coreImageContextOptions: [CIContextOption: Any]?

    /// Default pixel format for intermediate textures.
    public var workingPixelFormat: MTLPixelFormat = .bgra8Unorm

    /// Whether the render graph optimization is enabled. The default value for this property is NO.
    public var enablesRenderGraphOptimization = false

    /// Whether to enable native support for YCbCr textures. The default value for this property is YES.
    public var enablesYCbCrPixelFormatSupport = true

    /// A string to help identify this object.
    public var label: String = MTIContextDefaultLabel

    /// The built-in metal library URL.
    public var defaultLibraryURL: URL

    /// Makes the texture loader to use. When nil, the context uses `MTIDefaultTextureLoader`.
    public var makeTextureLoader: ((MTLDevice) -> any MTITextureLoader)?

    /// Makes the core video - metal texture bridge to use. When nil, the context uses
    /// `MTICVMetalIOSurfaceBridge`.
    public var makeCoreVideoMetalTextureBridge: ((MTLDevice) throws -> any MTICVMetalTextureBridging)?

    /// Makes the texture pool to use. When nil, the context picks a heap or device pool based on what
    /// the device supports.
    public var makeTexturePool: ((MTLDevice) -> any MTITexturePool)?

    public init() {
        defaultLibraryURL = MTIBuiltinLibraryURL()
    }
}

/// An evaluation context for rendering image processing results.
public final class MTIContext {
    public let workingPixelFormat: MTLPixelFormat
    public let isRenderGraphOptimizationEnabled: Bool
    public let label: String
    /// Whether the device supports MetalPerformanceShaders.
    public let isMetalPerformanceShadersSupported: Bool
    /// Whether the device supports YCbCr pixel formats.
    public let isYCbCrPixelFormatSupported: Bool
    /// Whether the device supports memoryless texture.
    public let isMemorylessTextureSupported: Bool
    /// Whether the device supports programmable blending.
    public let isProgrammableBlendingSupported: Bool
    /// Whether the default library is compiled with programmable blending support.
    public let defaultLibrarySupportsProgrammableBlending: Bool
    public let device: MTLDevice
    public let defaultLibrary: MTLLibrary
    public let commandQueue: MTLCommandQueue
    public let textureLoader: MTITextureLoader
    public let coreImageContext: CIContext
    public let coreVideoTextureBridge: MTICVMetalTextureBridging
    let texturePool: MTITexturePool
    private let defaultLibraryFunctionShort2FullNames: [String: String]
    private var libraryCache: [URL: MTLLibrary]
    private var functionCache: [MTIFunctionDescriptor: MTLFunction] = [:]
    private var renderPipelineCache: [MTLRenderPipelineDescriptor: MTIRenderPipeline] = [:]
    private var computePipelineCache: [MTLComputePipelineDescriptor: MTIComputePipeline] = [:]
    private var samplerStateCache: [MTISamplerDescriptor: MTLSamplerState] = [:]
    private let kernelStateMap: NSMapTable<AnyObject, KernelStateStore>
    private var promiseKeyValueTables: [String: MTIWeakToStrongObjectsMapTable<AnyObject, AnyObject>] = [:]
    private let promiseKeyValueTablesLock = OSAllocatedUnfairLock()
    private var imageKeyValueTables: [String: MTIWeakToStrongObjectsMapTable<AnyObject, AnyObject>] = [:]
    private let imageKeyValueTablesLock = OSAllocatedUnfairLock()
    private let promiseRenderTargetTable: NSMapTable<AnyObject, MTIImagePromiseRenderTarget>
    private let promiseRenderTargetTableLock = OSAllocatedUnfairLock()
    private let renderingLock = OSAllocatedUnfairLock()
    private static let instancesLock = OSAllocatedUnfairLock()
    private static let allInstances = NSPointerArray.weakObjects()
    private static let enablesSimulatorSupportLock = OSAllocatedUnfairLock()
    private static var _enablesSimulatorSupport = true

    /// Kernel states for one kernel, keyed by `MTIKernelConfiguration.identifier`. A reference type so it
    /// can be an `NSMapTable` value; the map table holds kernels weakly.
    private final class KernelStateStore {
        var states: [AnyHashable: Any] = [:]
    }

    /// Stand-in cache key for a kernel invoked without a configuration. All instances compare equal.
    private struct MTIKernelNoConfiguration: Hashable {}

    public convenience init(device: MTLDevice) throws {
        try self.init(device: device, options: MTIContextOptions())
    }

    public init(device: MTLDevice, options: MTIContextOptions) throws {
        #if targetEnvironment(simulator)
        if !MTIContext.enablesSimulatorSupport {
            throw MTIError.featureNotAvailableOnSimulator
        }
        #endif
        let defaultLibrary = if options.defaultLibraryURL.scheme == MTIURLSchemeForLibraryWithSource {
            try MTILibrarySourceRegistration.shared.newLibrary(
                with: options.defaultLibraryURL,
                device: device
            )
        } else {
            try device.makeLibrary(URL: options.defaultLibraryURL)
        }
        var short2FullNames: [String: String] = [:]
        for name in defaultLibrary.functionNames {
            let nameComponents = name.components(separatedBy: "::")
            if nameComponents.count > 1, let shortName = nameComponents.last {
                short2FullNames[shortName] = name
            }
        }
        defaultLibraryFunctionShort2FullNames = short2FullNames
        defaultLibrarySupportsProgrammableBlending = defaultLibrary.functionNames
            .contains("mti_haveColorArguments")
        label = options.label
        workingPixelFormat = options.workingPixelFormat
        isRenderGraphOptimizationEnabled = options.enablesRenderGraphOptimization
        self.device = device
        self.defaultLibrary = defaultLibrary
        coreImageContext = CIContext(mtlDevice: device, options: options.coreImageContextOptions)
        let commandQueue = device.makeCommandQueue()!
        commandQueue.label = options.label
        self.commandQueue = commandQueue
        isMetalPerformanceShadersSupported = MTIMPSSupportsMTLDevice(device)
        isYCbCrPixelFormatSupported = options
            .enablesYCbCrPixelFormatSupport && MTIDeviceSupportsYCBCRPixelFormat(device)
        isMemorylessTextureSupported = MTIContext.deviceSupportsMemorylessTexture(device)
        isProgrammableBlendingSupported = MTIContext.deviceSupportsProgrammableBlending(device)
        textureLoader = options.makeTextureLoader?(device) ?? MTIDefaultTextureLoader(device: device)
        texturePool = if let makeTexturePool = options.makeTexturePool {
            makeTexturePool(device)
        } else if MTIHeapTexturePool.isSupported(on: device) {
            MTIHeapTexturePool(device: device)
        } else {
            MTIDeviceTexturePool(device: device)
        }
        libraryCache = [options.defaultLibraryURL: defaultLibrary]
        kernelStateMap = NSMapTable(
            keyOptions: [.weakMemory, .objectPointerPersonality],
            valueOptions: [.strongMemory]
        )
        promiseRenderTargetTable = NSMapTable(
            keyOptions: [.weakMemory, .objectPointerPersonality],
            valueOptions: [.weakMemory]
        )
        coreVideoTextureBridge = try options.makeCoreVideoMetalTextureBridge?(device)
            ?? MTICVMetalIOSurfaceBridge(device: device)
        MTIContext.markInstanceCreation(self)
    }

    public static let defaultMetalDeviceSupportsMPS: Bool = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return false
        }
        return MTIMPSSupportsMTLDevice(device)
    }()

    public func reclaimResources() {
        texturePool.flush()
        coreVideoTextureBridge.flushCache()
        coreImageContext.clearCaches()
        imageKeyValueTablesLock.lock()
        for (_, table) in imageKeyValueTables {
            table.compact()
        }
        imageKeyValueTablesLock.unlock()
        promiseKeyValueTablesLock.lock()
        for (_, table) in promiseKeyValueTables {
            table.compact()
        }
        promiseKeyValueTablesLock.unlock()
    }

    public var idleResourceSize: Int {
        Int(texturePool.idleResourceSize)
    }

    public var idleResourceCount: Int {
        Int(texturePool.idleResourceCount)
    }

    public static func enumerateAllInstances(_ enumerator: (MTIContext) -> Void) {
        instancesTracking { instances in
            for case let context as MTIContext in instances.allObjects {
                enumerator(context)
            }
        }
    }

    /// Whether a device supports memoryless render targets.
    public static func deviceSupportsMemorylessTexture(_ device: MTLDevice) -> Bool {
        device.supportsFamily(.apple1)
    }

    /// Whether a device supports YCbCr pixel formats.
    public static func deviceSupportsYCbCrPixelFormat(_ device: MTLDevice) -> Bool {
        MTIDeviceSupportsYCBCRPixelFormat(device)
    }

    /// Whether a device supports programmable blending.
    public static func deviceSupportsProgrammableBlending(_ device: MTLDevice) -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return device.supportsFamily(.apple1)
        #endif
    }

    private static func instancesTracking(_ action: (NSPointerArray) -> Void) {
        instancesLock.lock()
        action(allInstances)
        instancesLock.unlock()
    }

    private static func markInstanceCreation(_ context: MTIContext) {
        instancesTracking { instances in
            instances.addPointer(Unmanaged.passUnretained(context).toOpaque())
            instances.addPointer(nil)
            instances.compact()
        }
    }

    /// Whether to render on iOS simulators. The default value is YES.
    public static var enablesSimulatorSupport: Bool {
        get {
            enablesSimulatorSupportLock.lock()
            defer {
                enablesSimulatorSupportLock.unlock()
            }
            return _enablesSimulatorSupport
        }
        set {
            enablesSimulatorSupportLock.lock()
            _enablesSimulatorSupport = newValue
            enablesSimulatorSupportLock.unlock()
        }
    }
}

public extension MTIContext {
    func makeRenderTarget(texture: MTLTexture) -> MTIImagePromiseRenderTarget {
        MTIImagePromiseRenderTarget(texture: texture)
    }

    func makeRenderTarget(reusableTextureDescriptor textureDescriptor: MTITextureDescriptor) throws
        -> MTIImagePromiseRenderTarget
    {
        let texture = try texturePool.makeTexture(descriptor: textureDescriptor)
        return MTIImagePromiseRenderTarget(reusableTexture: texture)
    }

    func lockForRendering() {
        renderingLock.lock()
    }

    func unlockForRendering() {
        renderingLock.unlock()
    }

    internal func library(with url: URL) throws -> MTLLibrary {
        if let library = libraryCache[url] {
            return library
        }
        let library = if url.scheme == MTIURLSchemeForLibraryWithSource {
            try MTILibrarySourceRegistration.shared.newLibrary(with: url, device: device)
        } else {
            try device.makeLibrary(URL: url)
        }
        libraryCache[url] = library
        return library
    }

    func function(with descriptor: MTIFunctionDescriptor) throws -> MTLFunction {
        if let cachedFunction = functionCache[descriptor] {
            return cachedFunction
        }
        var library = defaultLibrary
        if let libraryURL = descriptor.libraryURL {
            library = try self.library(with: libraryURL)
        }
        var functionName = descriptor.name
        if library === defaultLibrary {
            functionName = defaultLibraryFunctionShort2FullNames[descriptor.name] ?? functionName
        }
        let function = if let constantValues = descriptor.constantValues {
            try library.makeFunction(name: functionName, constantValues: constantValues)
        } else {
            library.makeFunction(name: functionName)
        }
        guard let function else {
            throw MTIError.functionNotFound
        }
        functionCache[descriptor] = function
        return function
    }

    func renderPipeline(with renderPipelineDescriptor: MTLRenderPipelineDescriptor) throws
        -> MTIRenderPipeline
    {
        if let renderPipeline = renderPipelineCache[renderPipelineDescriptor] {
            return renderPipeline
        }
        let key = renderPipelineDescriptor.copy() as! MTLRenderPipelineDescriptor
        var reflection: MTLRenderPipelineReflection?
        let renderPipelineState = try device.makeRenderPipelineState(
            descriptor: renderPipelineDescriptor,
            options: .bindingInfo,
            reflection: &reflection
        )
        let renderPipeline = MTIRenderPipeline(state: renderPipelineState, reflection: reflection!)
        renderPipelineCache[key] = renderPipeline
        return renderPipeline
    }

    func computePipeline(with computePipelineDescriptor: MTLComputePipelineDescriptor) throws
        -> MTIComputePipeline
    {
        if let computePipeline = computePipelineCache[computePipelineDescriptor] {
            return computePipeline
        }
        let key = computePipelineDescriptor.copy() as! MTLComputePipelineDescriptor
        var reflection: MTLComputePipelineReflection?
        let computePipelineState = try device.makeComputePipelineState(
            descriptor: computePipelineDescriptor,
            options: .bindingInfo,
            reflection: &reflection
        )
        let computePipeline = MTIComputePipeline(state: computePipelineState, reflection: reflection!)
        computePipelineCache[key] = computePipeline
        return computePipeline
    }

    func kernelState(for kernel: MTIKernel, configuration: MTIKernelConfiguration?) throws -> Any {
        let cacheKey: AnyHashable = configuration?.identifier ?? AnyHashable(MTIKernelNoConfiguration())
        if let cachedState = kernelStateMap.object(forKey: kernel)?.states[cacheKey] {
            return cachedState
        }
        let newState = try kernel.makeKernelState(context: self, configuration: configuration)
        if let states = kernelStateMap.object(forKey: kernel) {
            states.states[cacheKey] = newState
        } else {
            let newStates = KernelStateStore()
            newStates.states[cacheKey] = newState
            kernelStateMap.setObject(newStates, forKey: kernel)
        }
        return newState
    }

    func samplerState(with descriptor: MTISamplerDescriptor) throws -> MTLSamplerState {
        if let state = samplerStateCache[descriptor] {
            return state
        }
        guard let state = device.makeSamplerState(descriptor: descriptor.makeMTLSamplerDescriptor()) else {
            throw MTIError.failedToCreateSamplerState
        }
        samplerStateCache[descriptor] = state
        return state
    }

    func value(forPromise promise: Any, in tableName: MTIContextPromiseAssociatedValueTableName) -> Any? {
        promiseKeyValueTablesLock.lock()
        defer {
            promiseKeyValueTablesLock.unlock()
        }
        return promiseKeyValueTables[tableName.rawValue]?.object(forKey: promise as AnyObject)
    }

    func setValue(
        _ value: Any?,
        forPromise promise: Any,
        in tableName: MTIContextPromiseAssociatedValueTableName
    ) {
        promiseKeyValueTablesLock.lock()
        defer {
            promiseKeyValueTablesLock.unlock()
        }
        let table: MTIWeakToStrongObjectsMapTable<AnyObject, AnyObject>
        if let existing = promiseKeyValueTables[tableName.rawValue] {
            table = existing
        } else {
            table = MTIWeakToStrongObjectsMapTable()
            promiseKeyValueTables[tableName.rawValue] = table
        }
        table.setObject(value as AnyObject?, forKey: promise as AnyObject)
    }

    func value(forImage image: Any, in tableName: MTIContextImageAssociatedValueTableName) -> Any? {
        imageKeyValueTablesLock.lock()
        defer {
            imageKeyValueTablesLock.unlock()
        }
        return imageKeyValueTables[tableName.rawValue]?.object(forKey: image as AnyObject)
    }

    func setValue(_ value: Any?, forImage image: Any, in tableName: MTIContextImageAssociatedValueTableName) {
        imageKeyValueTablesLock.lock()
        defer {
            imageKeyValueTablesLock.unlock()
        }
        let table: MTIWeakToStrongObjectsMapTable<AnyObject, AnyObject>
        if let existing = imageKeyValueTables[tableName.rawValue] {
            table = existing
        } else {
            table = MTIWeakToStrongObjectsMapTable()
            imageKeyValueTables[tableName.rawValue] = table
        }
        table.setObject(value as AnyObject?, forKey: image as AnyObject)
    }

    func setRenderTarget(_ renderTarget: MTIImagePromiseRenderTarget, for promise: Any) {
        promiseRenderTargetTableLock.lock()
        promiseRenderTargetTable.setObject(renderTarget, forKey: promise as AnyObject)
        promiseRenderTargetTableLock.unlock()
    }

    func renderTarget(for promise: Any) -> MTIImagePromiseRenderTarget? {
        promiseRenderTargetTableLock.lock()
        defer {
            promiseRenderTargetTableLock.unlock()
        }
        return promiseRenderTargetTable.object(forKey: promise as AnyObject)
    }
}

public final class MTIImagePromiseRenderTarget {
    private let nonreusableTexture: MTLTexture?
    private let reusableTexture: MTIReusableTexture?

    fileprivate init(texture: MTLTexture) {
        nonreusableTexture = texture
        reusableTexture = nil
    }

    fileprivate init(reusableTexture: MTIReusableTexture) {
        nonreusableTexture = nil
        self.reusableTexture = reusableTexture
    }

    public var texture: MTLTexture? {
        if let nonreusableTexture {
            return nonreusableTexture
        }
        return reusableTexture?.texture
    }

    public func retainTexture() -> Bool {
        if nonreusableTexture != nil {
            return true
        }
        return reusableTexture?.retainTexture() ?? false
    }

    public func releaseTexture() {
        reusableTexture?.releaseTexture()
    }
}

public extension MTIContext {
    func startTaskToCreateCGImage(
        from image: MTIImage,
        colorSpace: CGColorSpace? = nil,
        completion: ((MTIRenderTask) -> Void)? = nil
    ) throws -> (image: CGImage, task: MTIRenderTask) {
        var outputCGImage: CGImage?
        let task = try startTask(
            toCreate: &outputCGImage,
            from: image,
            colorSpace: colorSpace,
            completion: completion
        )
        return (outputCGImage!, task)
    }
}
