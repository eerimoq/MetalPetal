//
//  MTIVector.swift
//  MetalPetal
//
//  Created by yi chen on 2017/7/25.
//

import CoreGraphics
import Foundation
import QuartzCore

public final class MTIVector: NSObject, NSCopying {
    public enum ScalarType: Int {
        case float
        case int
        case uint
        case short
        case ushort
        case char
        case uchar
    }

    private let data: NSData

    public let scalarType: ScalarType

    public let count: Int

    public init(floatValues values: UnsafePointer<Float>, count: UInt) {
        assert(count > 0)
        self.count = Int(count)
        data = NSData(bytes: values, length: Int(count) * MemoryLayout<Float>.stride)
        scalarType = .float
        super.init()
    }

    public init(intValues values: UnsafePointer<Int32>, count: UInt) {
        assert(count > 0)
        self.count = Int(count)
        data = NSData(bytes: values, length: Int(count) * MemoryLayout<Int32>.stride)
        scalarType = .int
        super.init()
    }

    public init(uintValues values: UnsafePointer<UInt32>, count: UInt) {
        assert(count > 0)
        self.count = Int(count)
        data = NSData(bytes: values, length: Int(count) * MemoryLayout<UInt32>.stride)
        scalarType = .uint
        super.init()
    }

    public init(shortValues values: UnsafePointer<Int16>, count: UInt) {
        assert(count > 0)
        self.count = Int(count)
        data = NSData(bytes: values, length: Int(count) * MemoryLayout<Int16>.stride)
        scalarType = .short
        super.init()
    }

    public init(ushortValues values: UnsafePointer<UInt16>, count: UInt) {
        assert(count > 0)
        self.count = Int(count)
        data = NSData(bytes: values, length: Int(count) * MemoryLayout<UInt16>.stride)
        scalarType = .ushort
        super.init()
    }

    public init(charValues values: UnsafePointer<Int8>, count: UInt) {
        assert(count > 0)
        self.count = Int(count)
        data = NSData(bytes: values, length: Int(count) * MemoryLayout<Int8>.stride)
        scalarType = .char
        super.init()
    }

    public init(ucharValues values: UnsafePointer<UInt8>, count: UInt) {
        assert(count > 0)
        self.count = Int(count)
        data = NSData(bytes: values, length: Int(count) * MemoryLayout<UInt8>.stride)
        scalarType = .uchar
        super.init()
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    override public var hash: Int {
        data.hash
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MTIVector else {
            return false
        }
        if other === self {
            return true
        }
        return count == other.count && data.isEqual(other.data)
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
            let b = bytes().assumingMemoryBound(to: Float.self)
            return CGPoint(x: CGFloat(b[0]), y: CGFloat(b[1]))
        }
        return .zero
    }

    public var cgSizeValue: CGSize {
        if count == 2, scalarType == .float {
            let b = bytes().assumingMemoryBound(to: Float.self)
            return CGSize(width: CGFloat(b[0]), height: CGFloat(b[1]))
        }
        return .zero
    }

    public var cgRectValue: CGRect {
        if count == 4, scalarType == .float {
            let b = bytes().assumingMemoryBound(to: Float.self)
            return CGRect(x: CGFloat(b[0]), y: CGFloat(b[1]), width: CGFloat(b[2]), height: CGFloat(b[3]))
        }
        return .zero
    }

    public var byteLength: Int {
        data.length
    }

    public func bytes() -> UnsafeRawPointer {
        data.bytes
    }
}

public extension MTIVector {
    convenience init(values: [Float]) {
        self.init(floatValues: values, count: UInt(values.count))
    }

    convenience init(values: [Int32]) {
        self.init(intValues: values, count: UInt(values.count))
    }

    convenience init(values: [UInt32]) {
        self.init(uintValues: values, count: UInt(values.count))
    }

    convenience init(values: [Int16]) {
        self.init(shortValues: values, count: UInt(values.count))
    }

    convenience init(values: [UInt16]) {
        self.init(ushortValues: values, count: UInt(values.count))
    }

    convenience init(values: [Int8]) {
        self.init(charValues: values, count: UInt(values.count))
    }

    convenience init(values: [UInt8]) {
        self.init(ucharValues: values, count: UInt(values.count))
    }
}
