//
//  MTITexturePool.swift
//  MetalPetal
//
//  Created by YuAo on 01/07/2017.
//

import Foundation
import Metal

private protocol MTITexturePoolInternal: MTITexturePool {
    func returnTexture(_ texture: MTLTexture, textureDescriptor: MTITextureDescriptor)
}

/// A texture pool which allocates and reuses metal textures.
public protocol MTITexturePool: AnyObject {
    static func newTexturePool(with device: MTLDevice) -> MTITexturePool

    func makeTexture(descriptor textureDescriptor: MTITextureDescriptor) throws -> MTIReusableTexture

    /// Frees as many textures from the pool as possible.
    func flush()

    /// The size in bytes occupied by idle resources.
    var idleResourceSize: Int { get }

    /// The count of idle resources.
    var idleResourceCount: Int { get }
}

/// A reusable texture from a texture pool.
public final class MTIReusableTexture {
    private let lock = MTILockCreate()
    private let textureDescriptor: MTITextureDescriptor
    private weak var pool: MTITexturePoolInternal?
    private var textureReferenceCount = 1
    private var valid = true
    private var heap: MTLHeap?
    private var _texture: MTLTexture?

    fileprivate init(texture: MTLTexture, descriptor: MTITextureDescriptor, pool: MTITexturePoolInternal) {
        _texture = texture
        textureDescriptor = descriptor.copy() as! MTITextureDescriptor
        self.pool = pool
        valid = true
        heap = texture.heap
    }

    /// Returns the underlying texture. When a reusable texture's texture retain count reaches zero, this
    /// returns nil.
    public var texture: MTLTexture? {
        lock.lock()
        defer { lock.unlock() }
        return _texture
    }

    /// Increase the texture's texture retain count. If the retain operation failed, i.e. the texture is
    /// already been reused and no longer valid, this returns `false`.
    public func retainTexture() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if valid {
            if textureReferenceCount <= 0 {
                NSException(
                    name: .internalInconsistencyException,
                    reason: "Retain a reusable texture after the _textureReferenceCount is less than 1.",
                    userInfo: nil
                ).raise()
            }
            textureReferenceCount += 1
            return true
        } else {
            return false
        }
    }

    /// Decrease the texture's texture retain count. When the retain count reaches zero, returns the
    /// underlying texture to the texture pool.
    public func releaseTexture() {
        var textureToReturn: MTLTexture?

        lock.lock()
        textureReferenceCount -= 1
        assert(textureReferenceCount >= 0, "Over release a reusable texture.")
        if textureReferenceCount == 0 {
            textureToReturn = _texture
            _texture = nil
            valid = false
        }
        lock.unlock()

        if let textureToReturn {
            pool?.returnTexture(textureToReturn, textureDescriptor: textureDescriptor)
            heap = nil
        }
    }

    deinit {
        if let texture = _texture {
            pool?.returnTexture(texture, textureDescriptor: textureDescriptor)
        }
    }
}

/// Device allocated texture pool.
public final class MTIDeviceTexturePool: NSObject, MTITexturePoolInternal {
    private let lock = MTILockCreate()
    private let device: MTLDevice
    private var textureCache: [MTITextureDescriptor: [MTLTexture]] = [:]

    public init(device: MTLDevice) {
        self.device = device
        super.init()
    }

    public static func newTexturePool(with device: MTLDevice) -> MTITexturePool {
        MTIDeviceTexturePool(device: device)
    }

    public func makeTexture(descriptor textureDescriptor: MTITextureDescriptor) throws -> MTIReusableTexture {
        lock.lock()
        var texture: MTLTexture?
        if var availableTextures = textureCache[textureDescriptor], !availableTextures.isEmpty {
            texture = availableTextures.removeLast()
            textureCache[textureDescriptor] = availableTextures
        }
        lock.unlock()

        if texture == nil {
            guard let newTexture = textureDescriptor.makeTexture(device: device) else {
                throw _MTIErrorCreate(.failedToCreateTexture, "MTIErrorFailedToCreateTexture", nil)
            }
            texture = newTexture
        }

        return MTIReusableTexture(texture: texture!, descriptor: textureDescriptor, pool: self)
    }

    fileprivate func returnTexture(_ texture: MTLTexture, textureDescriptor: MTITextureDescriptor) {
        lock.lock()
        textureCache[textureDescriptor, default: []].append(texture)
        lock.unlock()
    }

    public func flush() {
        lock.lock()
        textureCache.removeAll()
        lock.unlock()
    }

    public var idleResourceSize: Int {
        lock.lock()
        defer { lock.unlock() }
        var size = 0
        for (_, textures) in textureCache {
            for texture in textures {
                size += texture.allocatedSize
            }
        }
        return size
    }

    public var idleResourceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        var count = 0
        for (_, textures) in textureCache {
            count += textures.count
        }
        return count
    }
}

private struct MTIHeapTextureReuseKey: Hashable {
    let size: Int
    let resourceOptions: MTLResourceOptions

    func hash(into hasher: inout Hasher) {
        hasher.combine(size)
        hasher.combine(resourceOptions.rawValue)
    }
}

/// Heap texture pool. **May** have a smaller memory footprint than `MTIDeviceTexturePool` depending on your
/// use case. `MTIHeapTexturePool` uses `MTLHeap`s for texture allocations. Heaps are reused based on the
/// heap's size and resource options.
public final class MTIHeapTexturePool: NSObject, MTITexturePoolInternal {
    private let lock = MTILockCreate()
    private let device: MTLDevice
    private var heaps: [MTIHeapTextureReuseKey: [MTLHeap]] = [:]

    public init(device: MTLDevice) {
        assert(
            MTIHeapTexturePool.isSupported(on: device),
            """
            MTIHeapTexturePool is not supported on device: \(device). \
            See +[MTIHeapTexturePool isSupportedOnDevice:] for detail.
            """
        )
        self.device = device
        super.init()
    }

    public static func newTexturePool(with device: MTLDevice) -> MTITexturePool {
        MTIHeapTexturePool(device: device)
    }

    public func makeTexture(descriptor textureDescriptor: MTITextureDescriptor) throws -> MTIReusableTexture {
        lock.lock()
        let size = textureDescriptor.heapTextureSizeAndAlign(with: device).size
        let key = MTIHeapTextureReuseKey(size: size, resourceOptions: textureDescriptor.resourceOptions)
        var heap: MTLHeap?
        if var availableHeaps = heaps[key], !availableHeaps.isEmpty {
            heap = availableHeaps.removeLast()
            heaps[key] = availableHeaps
        }
        lock.unlock()

        if heap == nil {
            let heapDescriptor = MTLHeapDescriptor()
            heapDescriptor.size = key.size
            heapDescriptor.resourceOptions = key.resourceOptions
            if textureDescriptor.hazardTrackingMode == .default {
                heapDescriptor.hazardTrackingMode = .tracked
            }
            guard let newHeap = device.makeHeap(descriptor: heapDescriptor) else {
                throw _MTIErrorCreate(.failedToCreateHeap, "MTIErrorFailedToCreateHeap", nil)
            }
            heap = newHeap
        }

        guard let texture = textureDescriptor.makeTexture(heap: heap!) else {
            throw _MTIErrorCreate(.failedToCreateTexture, "MTIErrorFailedToCreateTexture", nil)
        }

        return MTIReusableTexture(texture: texture, descriptor: textureDescriptor, pool: self)
    }

    fileprivate func returnTexture(_ texture: MTLTexture, textureDescriptor: MTITextureDescriptor) {
        lock.lock()
        assert(texture.heap != nil)
        let size = textureDescriptor.heapTextureSizeAndAlign(with: device).size
        let key = MTIHeapTextureReuseKey(size: size, resourceOptions: textureDescriptor.resourceOptions)
        texture.makeAliasable()
        if let heap = texture.heap {
            heaps[key, default: []].append(heap)
        }
        lock.unlock()
    }

    public func flush() {
        lock.lock()
        heaps.removeAll()
        lock.unlock()
    }

    public var idleResourceSize: Int {
        lock.lock()
        defer { lock.unlock() }
        var size = 0
        for (_, heapList) in heaps {
            for heap in heapList {
                size += heap.currentAllocatedSize
            }
        }
        return size
    }

    public var idleResourceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        var count = 0
        for (_, heapList) in heaps {
            count += heapList.count
        }
        return count
    }

    /// MTIHeapTexturePool supports MTLGPUFamilyApple5, MTLGPUFamilyMac1 and MTLGPUFamilyMacCatalyst1 devices.
    public static func isSupported(on device: MTLDevice) -> Bool {
        // https://forums.developer.apple.com/thread/113223
        // This is a hardware limitation on pre-A12 devices. Texture resolutions must be padded out to powers
        // of two internally. Non-heap allocations can use virtual memory tricks to minimize this cost but
        // heaps cannot.
        device.supportsFamily(.apple5) || device.supportsFamily(.mac1) || device.supportsFamily(.macCatalyst1)
    }
}
