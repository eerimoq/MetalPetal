//
//  MTIVertex.swift
//  Pods
//
//  Created by YuAo on 30/06/2017.
//
//

import Foundation
import Metal

public extension MTIVertex {
    init(position: (Float, Float, Float, Float), textureCoordinate: (Float, Float)) {
        self.init()
        self.position = SIMD4<Float>(position.0, position.1, position.2, position.3)
        self.textureCoordinate = SIMD2<Float>(textureCoordinate.0, textureCoordinate.1)
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

public extension MTIVertices {
    convenience init(vertices: [MTIVertex], primitiveType: MTLPrimitiveType) {
        self.init(__vertices: vertices, count: UInt(vertices.count), primitiveType: primitiveType)
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
        self.init(__mtiVertices: mtiVertices, count: UInt(mtiVertices.count))
    }

    convenience init?(uint32Indexes: [UInt32]) {
        self.init(__uInt32Indexes: uint32Indexes, count: UInt(uint32Indexes.count))
    }
}
