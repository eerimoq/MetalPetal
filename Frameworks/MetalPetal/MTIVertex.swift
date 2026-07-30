//
//  MTIVertex.swift
//  MetalPetal
//
//  Created by YuAo on 25/06/2017.
//

import CoreGraphics
import Foundation
import Metal
import simd

public extension MTIVertex {
    init(x: Float, y: Float, z: Float, w: Float, u: Float, v: Float) {
        self.init()
        position = SIMD4<Float>(x, y, z, w)
        textureCoordinate = SIMD2<Float>(u, v)
    }

    init(position: (Float, Float, Float, Float), textureCoordinate: (Float, Float)) {
        self.init()
        self.position = SIMD4<Float>(position.0, position.1, position.2, position.3)
        self.textureCoordinate = SIMD2<Float>(textureCoordinate.0, textureCoordinate.1)
    }

    func isEqual(to other: MTIVertex) -> Bool {
        position == other.position && textureCoordinate == other.textureCoordinate
    }
}

extension MTIVertex: @retroactive Equatable {
    public static func == (lhs: MTIVertex, rhs: MTIVertex) -> Bool {
        lhs.isEqual(to: rhs)
    }
}

extension MTIVertex: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(position)
        hasher.combine(textureCoordinate)
    }
}

private protocol MTIVertexBufferStorage: AnyObject {
    var contents: UnsafeRawPointer { get }
    func encodeToVertexBuffer(at index: Int, with commandEncoder: MTLRenderCommandEncoder)
}

private final class MTIMallocVertexBuffer: MTIVertexBufferStorage {
    private let memory: UnsafeMutableRawPointer
    private let length: Int

    init(contents bytes: UnsafeRawPointer, length: Int) {
        memory = malloc(length)
        memcpy(memory, bytes, length)
        self.length = length
    }

    deinit {
        free(memory)
    }

    var contents: UnsafeRawPointer {
        UnsafeRawPointer(memory)
    }

    func encodeToVertexBuffer(at index: Int, with commandEncoder: MTLRenderCommandEncoder) {
        commandEncoder.setVertexBytes(memory, length: length, index: index)
    }
}

extension MTIDataBuffer: MTIVertexBufferStorage {
    fileprivate var contents: UnsafeRawPointer {
        var result: UnsafeRawPointer!
        unsafeAccess { pointer, _ in
            result = UnsafeRawPointer(pointer)
        }
        return result
    }

    fileprivate func encodeToVertexBuffer(at index: Int, with commandEncoder: MTLRenderCommandEncoder) {
        if let buffer = buffer(for: commandEncoder.device) {
            commandEncoder.setVertexBuffer(buffer, offset: 0, index: index)
        }
    }
}

/// A MTIGeometry implementation. A MTIVertices contains MTIVertex data structures. It is designed to handle a
/// small amount of vertices. A MTIVertices bounds its contents to the vertex buffer with index of 0.
public final class MTIVertices: NSObject, MTIGeometry {
    public let vertexCount: Int

    public let indexCount: Int

    public let primitiveType: MTLPrimitiveType

    private let vertexBuffer: MTIVertexBufferStorage

    private let indexBuffer: MTIDataBuffer?

    public init(vertices: UnsafePointer<MTIVertex>, count: UInt, primitiveType: MTLPrimitiveType) {
        assert(count > 0)
        vertexCount = Int(count)
        self.primitiveType = primitiveType
        let bufferLength = Int(count) * MemoryLayout<MTIVertex>.stride
        if bufferLength < 4096 {
            vertexBuffer = MTIMallocVertexBuffer(contents: UnsafeRawPointer(vertices), length: bufferLength)
        } else {
            vertexBuffer = MTIDataBuffer(bytes: vertices, length: UInt(bufferLength), options: [])!
        }
        indexBuffer = nil
        indexCount = 0
        super.init()
    }

    public init(
        vertexBuffer: MTIDataBuffer,
        vertexCount: UInt,
        indexBuffer: MTIDataBuffer?,
        indexCount: UInt,
        primitiveType: MTLPrimitiveType
    ) {
        assert(vertexCount > 0)
        assert(Int(vertexBuffer.length) == Int(vertexCount) * MemoryLayout<MTIVertex>.stride)
        assert(indexBuffer == nil || Int(indexBuffer!.length) == Int(indexCount) * MemoryLayout<UInt32>.stride)
        self.vertexCount = Int(vertexCount)
        self.indexCount = Int(indexCount)
        self.primitiveType = primitiveType
        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
        super.init()
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    override public var hash: Int {
        var hasher = Hasher()
        let vertices = vertexBuffer.contents.assumingMemoryBound(to: MTIVertex.self)
        for index in 0 ..< vertexCount {
            let v = vertices[index]
            hasher.combine(v.position.x)
            hasher.combine(v.position.y)
            hasher.combine(v.position.z)
            hasher.combine(v.position.w)
            hasher.combine(v.textureCoordinate.x)
            hasher.combine(v.textureCoordinate.y)
        }
        let indexes = vertexBuffer.contents.assumingMemoryBound(to: UInt32.self)
        for index in 0 ..< indexCount {
            hasher.combine(indexes[index])
        }
        return hasher.finalize()
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MTIVertices else {
            return false
        }
        if other === self {
            return true
        }
        guard vertexCount == other.vertexCount, indexCount == other.indexCount else {
            return false
        }
        let v1 = vertexBuffer.contents.assumingMemoryBound(to: MTIVertex.self)
        let v2 = other.vertexBuffer.contents.assumingMemoryBound(to: MTIVertex.self)
        for index in 0 ..< vertexCount where !v1[index].isEqual(to: v2[index]) {
            return false
        }
        if let indexBuffer, let otherIndexBuffer = other.indexBuffer {
            let i1 = indexBuffer.contents.assumingMemoryBound(to: UInt32.self)
            let i2 = otherIndexBuffer.contents.assumingMemoryBound(to: UInt32.self)
            for index in 0 ..< indexCount where i1[index] != i2[index] {
                return false
            }
        }
        return true
    }

    public static func squareVertices(for rect: CGRect) -> MTIVertices {
        let l = Float(rect.minX)
        let r = Float(rect.maxX)
        let t = Float(rect.minY)
        let b = Float(rect.maxY)
        return MTIVertices(vertices: [
            MTIVertex(position: (l, t, 0, 1), textureCoordinate: (0, 1)),
            MTIVertex(position: (r, t, 0, 1), textureCoordinate: (1, 1)),
            MTIVertex(position: (l, b, 0, 1), textureCoordinate: (0, 0)),
            MTIVertex(position: (r, b, 0, 1), textureCoordinate: (1, 0)),
        ], primitiveType: .triangleStrip)
    }

    public static func verticallyFlippedSquareVertices(for rect: CGRect) -> MTIVertices {
        let l = Float(rect.minX)
        let r = Float(rect.maxX)
        let t = Float(rect.minY)
        let b = Float(rect.maxY)
        return MTIVertices(vertices: [
            MTIVertex(position: (l, t, 0, 1), textureCoordinate: (0, 0)),
            MTIVertex(position: (r, t, 0, 1), textureCoordinate: (1, 0)),
            MTIVertex(position: (l, b, 0, 1), textureCoordinate: (0, 1)),
            MTIVertex(position: (r, b, 0, 1), textureCoordinate: (1, 1)),
        ], primitiveType: .triangleStrip)
    }

    public static let fullViewportSquare: MTIVertices =
        squareVertices(for: CGRect(x: -1, y: -1, width: 2, height: 2))

    public func encodeDrawCall(
        with commandEncoder: MTLRenderCommandEncoder,
        context _: MTIGeometryRenderingContext
    ) {
        // assuming buffer bounded to index 0.
        vertexBuffer.encodeToVertexBuffer(at: 0, with: commandEncoder)
        if let indexBuffer, let buffer = indexBuffer.buffer(for: commandEncoder.device) {
            commandEncoder.drawIndexedPrimitives(
                type: primitiveType,
                indexCount: indexCount,
                indexType: .uint32,
                indexBuffer: buffer,
                indexBufferOffset: 0
            )
        } else {
            commandEncoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: vertexCount)
        }
    }
}

public extension MTIVertices {
    convenience init(vertices: [MTIVertex], primitiveType: MTLPrimitiveType) {
        self.init(vertices: vertices, count: UInt(vertices.count), primitiveType: primitiveType)
    }

    convenience init(
        vertexBuffer: MTIDataBuffer,
        vertexCount: Int,
        indexBuffer: MTIDataBuffer?,
        indexCount: Int?,
        primitiveType: MTLPrimitiveType
    ) {
        self.init(
            vertexBuffer: vertexBuffer,
            vertexCount: UInt(vertexCount),
            indexBuffer: indexBuffer,
            indexCount: UInt(indexCount ?? 0),
            primitiveType: primitiveType
        )
    }
}

public extension MTIDataBuffer {
    convenience init?(mtiVertices: [MTIVertex]) {
        self.init(
            bytes: mtiVertices,
            length: UInt(mtiVertices.count * MemoryLayout<MTIVertex>.stride),
            options: []
        )
    }

    convenience init?(uint32Indexes: [UInt32]) {
        self.init(
            bytes: uint32Indexes,
            length: UInt(uint32Indexes.count * MemoryLayout<UInt32>.stride),
            options: []
        )
    }
}
