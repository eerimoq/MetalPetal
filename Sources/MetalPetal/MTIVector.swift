//
//  MTIVector.swift
//  MetalPetal
//
//  Created by yi chen on 2017/7/25.
//

import CoreGraphics
import Foundation
import QuartzCore

public final class MTIVector: Hashable {
    public enum ScalarType: Int {
        case float
        case int
        case uint
        case short
        case ushort
        case char
        case uchar
    }

    private let data: Data

    public let scalarType: ScalarType

    public let count: Int

    public init(floatValues values: UnsafePointer<Float>, count: Int) {
        self.count = count
        data = Data(bytes: values, count: count * MemoryLayout<Float>.stride)
        scalarType = .float
    }

    public init(intValues values: UnsafePointer<Int32>, count: Int) {
        self.count = count
        data = Data(bytes: values, count: count * MemoryLayout<Int32>.stride)
        scalarType = .int
    }

    public init(uintValues values: UnsafePointer<UInt32>, count: Int) {
        self.count = count
        data = Data(bytes: values, count: count * MemoryLayout<UInt32>.stride)
        scalarType = .uint
    }

    public init(shortValues values: UnsafePointer<Int16>, count: Int) {
        self.count = count
        data = Data(bytes: values, count: count * MemoryLayout<Int16>.stride)
        scalarType = .short
    }

    public init(ushortValues values: UnsafePointer<UInt16>, count: Int) {
        self.count = count
        data = Data(bytes: values, count: count * MemoryLayout<UInt16>.stride)
        scalarType = .ushort
    }

    public init(charValues values: UnsafePointer<Int8>, count: Int) {
        self.count = count
        data = Data(bytes: values, count: count * MemoryLayout<Int8>.stride)
        scalarType = .char
    }

    public init(ucharValues values: UnsafePointer<UInt8>, count: Int) {
        self.count = count
        data = Data(bytes: values, count: count * MemoryLayout<UInt8>.stride)
        scalarType = .uchar
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }

    public static func == (lhs: MTIVector, rhs: MTIVector) -> Bool {
        if lhs === rhs {
            return true
        }
        return lhs.count == rhs.count && lhs.data == rhs.data
    }

    public convenience init(x: Float, y: Float) {
        let values: [Float] = [x, y]
        self.init(floatValues: values, count: 2)
    }

    public convenience init(value point: CGPoint) {
        let values: [Float] = [Float(point.x), Float(point.y)]
        self.init(floatValues: values, count: 2)
    }

    public convenience init(value size: CGSize) {
        let values: [Float] = [Float(size.width), Float(size.height)]
        self.init(floatValues: values, count: 2)
    }

    public convenience init(value rect: CGRect) {
        let values: [Float] = [
            Float(rect.origin.x),
            Float(rect.origin.y),
            Float(rect.size.width),
            Float(rect.size.height),
        ]
        self.init(floatValues: values, count: 4)
    }

    public var cgPointValue: CGPoint {
        if count == 2, scalarType == .float {
            return withUnsafeBytes { raw in
                let b = raw.bindMemory(to: Float.self)
                return CGPoint(x: CGFloat(b[0]), y: CGFloat(b[1]))
            }
        }
        return .zero
    }

    public var cgSizeValue: CGSize {
        if count == 2, scalarType == .float {
            return withUnsafeBytes { raw in
                let b = raw.bindMemory(to: Float.self)
                return CGSize(width: CGFloat(b[0]), height: CGFloat(b[1]))
            }
        }
        return .zero
    }

    public var cgRectValue: CGRect {
        if count == 4, scalarType == .float {
            return withUnsafeBytes { raw in
                let b = raw.bindMemory(to: Float.self)
                return CGRect(x: CGFloat(b[0]), y: CGFloat(b[1]), width: CGFloat(b[2]), height: CGFloat(b[3]))
            }
        }
        return .zero
    }

    public var byteLength: Int {
        data.count
    }

    /// Calls `body` with the vector's raw bytes. The pointer is only valid for the duration of the
    /// call; this replaces the previous `bytes()`, which handed out an unowned interior pointer.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try data.withUnsafeBytes(body)
    }
}

public extension MTIVector {
    convenience init(values: [Float]) {
        self.init(floatValues: values, count: values.count)
    }

    convenience init(values: [Int32]) {
        self.init(intValues: values, count: values.count)
    }

    convenience init(values: [UInt32]) {
        self.init(uintValues: values, count: values.count)
    }

    convenience init(values: [Int16]) {
        self.init(shortValues: values, count: values.count)
    }

    convenience init(values: [UInt16]) {
        self.init(ushortValues: values, count: values.count)
    }

    convenience init(values: [Int8]) {
        self.init(charValues: values, count: values.count)
    }

    convenience init(values: [UInt8]) {
        self.init(ucharValues: values, count: values.count)
    }
}
