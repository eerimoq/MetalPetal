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

public struct MTIVertex: Hashable {
    public var position: SIMD4<Float>
    public var textureCoordinate: SIMD2<Float>

    public init() {
        position = SIMD4<Float>()
        textureCoordinate = SIMD2<Float>()
    }
}

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
public final class MTIVertices: MTIGeometry, Hashable {
    public let vertexCount: Int

    public let indexCount: Int

    public let primitiveType: MTLPrimitiveType

    private let vertexBuffer: MTIVertexBufferStorage

    private let indexBuffer: MTIDataBuffer?

    public init(vertices: UnsafePointer<MTIVertex>, count: Int, primitiveType: MTLPrimitiveType) {
        vertexCount = count
        self.primitiveType = primitiveType
        let bufferLength = count * MemoryLayout<MTIVertex>.stride
        if bufferLength < 4096 {
            vertexBuffer = MTIMallocVertexBuffer(contents: UnsafeRawPointer(vertices), length: bufferLength)
        } else {
            vertexBuffer = MTIDataBuffer(bytes: vertices, length: Int(bufferLength), options: [])!
        }
        indexBuffer = nil
        indexCount = 0
    }

    public init(
        vertexBuffer: MTIDataBuffer,
        vertexCount: Int,
        indexBuffer: MTIDataBuffer?,
        indexCount: Int,
        primitiveType: MTLPrimitiveType
    ) {
        self.vertexCount = vertexCount
        self.indexCount = indexCount
        self.primitiveType = primitiveType
        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
    }

    public func hash(into hasher: inout Hasher) {
        let vertices = vertexBuffer.contents.assumingMemoryBound(to: MTIVertex.self)
        for index in 0 ..< vertexCount {
            hasher.combine(vertices[index])
        }
        // Read the indexes from `indexBuffer`, not `vertexBuffer`. Reading them from the vertex buffer
        // both weakened the hash and could read past its end when indexCount * 4 exceeded its length.
        if let indexBuffer {
            let indexes = indexBuffer.contents.assumingMemoryBound(to: UInt32.self)
            for index in 0 ..< indexCount {
                hasher.combine(indexes[index])
            }
        }
    }

    public static func == (lhs: MTIVertices, rhs: MTIVertices) -> Bool {
        if lhs === rhs {
            return true
        }
        guard lhs.vertexCount == rhs.vertexCount, lhs.indexCount == rhs.indexCount else {
            return false
        }
        let v1 = lhs.vertexBuffer.contents.assumingMemoryBound(to: MTIVertex.self)
        let v2 = rhs.vertexBuffer.contents.assumingMemoryBound(to: MTIVertex.self)
        for index in 0 ..< lhs.vertexCount where v1[index] != v2[index] {
            return false
        }
        if let lhsIndexBuffer = lhs.indexBuffer, let rhsIndexBuffer = rhs.indexBuffer {
            let i1 = lhsIndexBuffer.contents.assumingMemoryBound(to: UInt32.self)
            let i2 = rhsIndexBuffer.contents.assumingMemoryBound(to: UInt32.self)
            for index in 0 ..< lhs.indexCount where i1[index] != i2[index] {
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
        self.init(vertices: vertices, count: vertices.count, primitiveType: primitiveType)
    }
}

public extension MTIDataBuffer {
    convenience init?(mtiVertices: [MTIVertex]) {
        self.init(
            bytes: mtiVertices,
            length: Int(mtiVertices.count * MemoryLayout<MTIVertex>.stride),
            options: []
        )
    }

    convenience init?(uint32Indexes: [UInt32]) {
        self.init(
            bytes: uint32Indexes,
            length: Int(uint32Indexes.count * MemoryLayout<UInt32>.stride),
            options: []
        )
    }
}
