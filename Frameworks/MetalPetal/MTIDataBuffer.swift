//
//  MTIDataBuffer.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/1/22.
//

import Foundation
import Metal

private final class MTIPageAlignedBuffer {
    let contents: UnsafeMutableRawPointer
    let size: vm_size_t
    let address: vm_address_t

    init?(length: Int) {
        var pageSize: vm_size_t = 0
        let pageSizeRequestResult = host_page_size(mach_host_self(), &pageSize)
        if pageSizeRequestResult != KERN_SUCCESS {
            return nil
        }
        let pageSizeInt = Int(pageSize)
        let alignedSize = vm_size_t((length + (pageSizeInt - 1)) / pageSizeInt * pageSizeInt)
        var address: vm_address_t = 0
        let result = vm_allocate(mach_task_self_, &address, alignedSize, VM_FLAGS_ANYWHERE)
        if result != KERN_SUCCESS {
            return nil
        }
        guard let contents = UnsafeMutableRawPointer(bitPattern: address) else {
            vm_deallocate(mach_task_self_, address, alignedSize)
            return nil
        }
        self.address = address
        size = alignedSize
        self.contents = contents
    }

    deinit {
        if size != 0 {
            vm_deallocate(mach_task_self_, address, size)
        }
    }
}

/// A GPU mutable data buffer. You can pass a `MTIDataBuffer` instance to multiple processing units, they can
/// all read and write the buffer's content. However, accessing a `MTIDataBuffer`'s contents using CPU is not
/// safe. You must ensure all the GPU reads/writes to this buffer are completed. For one `MTIDataBuffer`
/// instance, one and only one underlying `MTLBuffer` will be created for one GPU device.
public final class MTIDataBuffer: NSObject {
    private let alignedBuffer: MTIPageAlignedBuffer

    public let length: UInt

    public let options: MTLResourceOptions

    private let bufferCache: NSMapTable<AnyObject, AnyObject>
    private let bufferCacheLock = MTILockCreate()

    public init?(length: UInt, options: MTLResourceOptions) {
        guard let alignedBuffer = MTIPageAlignedBuffer(length: Int(length)) else {
            return nil
        }
        self.alignedBuffer = alignedBuffer
        self.length = length
        self.options = options
        bufferCache = NSMapTable(
            keyOptions: [.objectPointerPersonality, .weakMemory],
            valueOptions: [.objectPointerPersonality, .strongMemory]
        )
        super.init()
    }

    public convenience init?(bytes: UnsafeRawPointer, length: UInt, options: MTLResourceOptions) {
        self.init(length: length, options: options)
        memcpy(alignedBuffer.contents, bytes, Int(length))
    }

    public convenience init?(data: Data, options: MTLResourceOptions) {
        let bytes = [UInt8](data)
        self.init(bytes: bytes, length: UInt(bytes.count), options: options)
    }

    public func buffer(for device: MTLDevice) -> MTLBuffer? {
        bufferCacheLock.lock()
        defer { bufferCacheLock.unlock() }

        if let buffer = bufferCache.object(forKey: device) as? MTLBuffer {
            return buffer
        }

        let alignedBuffer = alignedBuffer
        let buffer = device.makeBuffer(
            bytesNoCopy: alignedBuffer.contents,
            length: Int(alignedBuffer.size),
            options: options,
            deallocator: { _, _ in
                // Keep the aligned buffer alive as long as the MTLBuffer references its memory.
                _ = alignedBuffer
            }
        )

        if let buffer {
            bufferCache.setObject(buffer, forKey: device)
        }
        return buffer
    }

    public func unsafeAccess(_ block: (UnsafeMutableRawPointer, UInt) -> Void) {
        block(alignedBuffer.contents, length)
    }
}

public extension MTIDataBuffer {
    convenience init?<T>(values: [T], options: MTLResourceOptions = []) {
        self.init(bytes: values, length: UInt(MemoryLayout<T>.size * values.count), options: options)
    }

    func unsafeAccess<ReturnType,
        BufferContentType>(_ block: (UnsafeMutableBufferPointer<BufferContentType>) throws
        -> ReturnType) rethrows -> ReturnType
    {
        var buffer: UnsafeMutableBufferPointer<BufferContentType>!
        unsafeAccess { (pointer: UnsafeMutableRawPointer, length: UInt) in
            precondition(Int(length) % MemoryLayout<BufferContentType>.stride == 0)
            let count = Int(length) / MemoryLayout<BufferContentType>.stride
            buffer = UnsafeMutableBufferPointer(
                start: pointer.bindMemory(to: BufferContentType.self, capacity: count),
                count: count
            )
        }
        return try block(buffer)
    }
}
