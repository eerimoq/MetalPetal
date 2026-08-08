//
// This is an auto-generated source file.
//

import Foundation
import simd

public extension MTIVector {
    init(value: simd_float2) {
        var v = value
        let count = MemoryLayout<simd_float2>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float2() -> simd_float2 {
        var value = simd_float2()
        if scalarType == .float, byteLength == MemoryLayout<simd_float2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float3) {
        var v = value
        let count = MemoryLayout<simd_float3>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float3() -> simd_float3 {
        var value = simd_float3()
        if scalarType == .float, byteLength == MemoryLayout<simd_float3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float4) {
        var v = value
        let count = MemoryLayout<simd_float4>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float4() -> simd_float4 {
        var value = simd_float4()
        if scalarType == .float, byteLength == MemoryLayout<simd_float4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float2x2) {
        var v = value
        let count = MemoryLayout<simd_float2x2>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float2x2() -> simd_float2x2 {
        var value = simd_float2x2()
        if scalarType == .float, byteLength == MemoryLayout<simd_float2x2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float2x2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float2x3) {
        var v = value
        let count = MemoryLayout<simd_float2x3>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float2x3() -> simd_float2x3 {
        var value = simd_float2x3()
        if scalarType == .float, byteLength == MemoryLayout<simd_float2x3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float2x3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float2x4) {
        var v = value
        let count = MemoryLayout<simd_float2x4>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float2x4() -> simd_float2x4 {
        var value = simd_float2x4()
        if scalarType == .float, byteLength == MemoryLayout<simd_float2x4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float2x4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float3x2) {
        var v = value
        let count = MemoryLayout<simd_float3x2>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float3x2() -> simd_float3x2 {
        var value = simd_float3x2()
        if scalarType == .float, byteLength == MemoryLayout<simd_float3x2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float3x2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float3x3) {
        var v = value
        let count = MemoryLayout<simd_float3x3>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float3x3() -> simd_float3x3 {
        var value = simd_float3x3()
        if scalarType == .float, byteLength == MemoryLayout<simd_float3x3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float3x3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float3x4) {
        var v = value
        let count = MemoryLayout<simd_float3x4>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float3x4() -> simd_float3x4 {
        var value = simd_float3x4()
        if scalarType == .float, byteLength == MemoryLayout<simd_float3x4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float3x4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float4x2) {
        var v = value
        let count = MemoryLayout<simd_float4x2>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float4x2() -> simd_float4x2 {
        var value = simd_float4x2()
        if scalarType == .float, byteLength == MemoryLayout<simd_float4x2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float4x2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float4x3) {
        var v = value
        let count = MemoryLayout<simd_float4x3>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float4x3() -> simd_float4x3 {
        var value = simd_float4x3()
        if scalarType == .float, byteLength == MemoryLayout<simd_float4x3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float4x3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_float4x4) {
        var v = value
        let count = MemoryLayout<simd_float4x4>.size / MemoryLayout<Float>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Float.self)) }
        self.init(floatValues: scalars, count: count)
    }

    func float4x4() -> simd_float4x4 {
        var value = simd_float4x4()
        if scalarType == .float, byteLength == MemoryLayout<simd_float4x4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_float4x4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_int2) {
        var v = value
        let count = MemoryLayout<simd_int2>.size / MemoryLayout<Int32>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int32.self)) }
        self.init(intValues: scalars, count: count)
    }

    func int2() -> simd_int2 {
        var value = simd_int2()
        if scalarType == .int, byteLength == MemoryLayout<simd_int2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_int2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_int3) {
        var v = value
        let count = MemoryLayout<simd_int3>.size / MemoryLayout<Int32>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int32.self)) }
        self.init(intValues: scalars, count: count)
    }

    func int3() -> simd_int3 {
        var value = simd_int3()
        if scalarType == .int, byteLength == MemoryLayout<simd_int3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_int3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_int4) {
        var v = value
        let count = MemoryLayout<simd_int4>.size / MemoryLayout<Int32>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int32.self)) }
        self.init(intValues: scalars, count: count)
    }

    func int4() -> simd_int4 {
        var value = simd_int4()
        if scalarType == .int, byteLength == MemoryLayout<simd_int4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_int4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_uint2) {
        var v = value
        let count = MemoryLayout<simd_uint2>.size / MemoryLayout<UInt32>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt32.self)) }
        self.init(uintValues: scalars, count: count)
    }

    func uint2() -> simd_uint2 {
        var value = simd_uint2()
        if scalarType == .uint, byteLength == MemoryLayout<simd_uint2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_uint2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_uint3) {
        var v = value
        let count = MemoryLayout<simd_uint3>.size / MemoryLayout<UInt32>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt32.self)) }
        self.init(uintValues: scalars, count: count)
    }

    func uint3() -> simd_uint3 {
        var value = simd_uint3()
        if scalarType == .uint, byteLength == MemoryLayout<simd_uint3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_uint3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_uint4) {
        var v = value
        let count = MemoryLayout<simd_uint4>.size / MemoryLayout<UInt32>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt32.self)) }
        self.init(uintValues: scalars, count: count)
    }

    func uint4() -> simd_uint4 {
        var value = simd_uint4()
        if scalarType == .uint, byteLength == MemoryLayout<simd_uint4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_uint4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_short2) {
        var v = value
        let count = MemoryLayout<simd_short2>.size / MemoryLayout<Int16>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int16.self)) }
        self.init(shortValues: scalars, count: count)
    }

    func short2() -> simd_short2 {
        var value = simd_short2()
        if scalarType == .short, byteLength == MemoryLayout<simd_short2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_short2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_short3) {
        var v = value
        let count = MemoryLayout<simd_short3>.size / MemoryLayout<Int16>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int16.self)) }
        self.init(shortValues: scalars, count: count)
    }

    func short3() -> simd_short3 {
        var value = simd_short3()
        if scalarType == .short, byteLength == MemoryLayout<simd_short3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_short3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_short4) {
        var v = value
        let count = MemoryLayout<simd_short4>.size / MemoryLayout<Int16>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int16.self)) }
        self.init(shortValues: scalars, count: count)
    }

    func short4() -> simd_short4 {
        var value = simd_short4()
        if scalarType == .short, byteLength == MemoryLayout<simd_short4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_short4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_ushort2) {
        var v = value
        let count = MemoryLayout<simd_ushort2>.size / MemoryLayout<UInt16>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt16.self)) }
        self.init(ushortValues: scalars, count: count)
    }

    func ushort2() -> simd_ushort2 {
        var value = simd_ushort2()
        if scalarType == .ushort, byteLength == MemoryLayout<simd_ushort2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_ushort2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_ushort3) {
        var v = value
        let count = MemoryLayout<simd_ushort3>.size / MemoryLayout<UInt16>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt16.self)) }
        self.init(ushortValues: scalars, count: count)
    }

    func ushort3() -> simd_ushort3 {
        var value = simd_ushort3()
        if scalarType == .ushort, byteLength == MemoryLayout<simd_ushort3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_ushort3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_ushort4) {
        var v = value
        let count = MemoryLayout<simd_ushort4>.size / MemoryLayout<UInt16>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt16.self)) }
        self.init(ushortValues: scalars, count: count)
    }

    func ushort4() -> simd_ushort4 {
        var value = simd_ushort4()
        if scalarType == .ushort, byteLength == MemoryLayout<simd_ushort4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_ushort4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_char2) {
        var v = value
        let count = MemoryLayout<simd_char2>.size / MemoryLayout<Int8>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int8.self)) }
        self.init(charValues: scalars, count: count)
    }

    func char2() -> simd_char2 {
        var value = simd_char2()
        if scalarType == .char, byteLength == MemoryLayout<simd_char2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_char2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_char3) {
        var v = value
        let count = MemoryLayout<simd_char3>.size / MemoryLayout<Int8>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int8.self)) }
        self.init(charValues: scalars, count: count)
    }

    func char3() -> simd_char3 {
        var value = simd_char3()
        if scalarType == .char, byteLength == MemoryLayout<simd_char3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_char3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_char4) {
        var v = value
        let count = MemoryLayout<simd_char4>.size / MemoryLayout<Int8>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: Int8.self)) }
        self.init(charValues: scalars, count: count)
    }

    func char4() -> simd_char4 {
        var value = simd_char4()
        if scalarType == .char, byteLength == MemoryLayout<simd_char4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_char4>.size)
                }
            }
        }
        return value
    }

    init(value: simd_uchar2) {
        var v = value
        let count = MemoryLayout<simd_uchar2>.size / MemoryLayout<UInt8>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt8.self)) }
        self.init(ucharValues: scalars, count: count)
    }

    func uchar2() -> simd_uchar2 {
        var value = simd_uchar2()
        if scalarType == .uchar, byteLength == MemoryLayout<simd_uchar2>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_uchar2>.size)
                }
            }
        }
        return value
    }

    init(value: simd_uchar3) {
        var v = value
        let count = MemoryLayout<simd_uchar3>.size / MemoryLayout<UInt8>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt8.self)) }
        self.init(ucharValues: scalars, count: count)
    }

    func uchar3() -> simd_uchar3 {
        var value = simd_uchar3()
        if scalarType == .uchar, byteLength == MemoryLayout<simd_uchar3>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_uchar3>.size)
                }
            }
        }
        return value
    }

    init(value: simd_uchar4) {
        var v = value
        let count = MemoryLayout<simd_uchar4>.size / MemoryLayout<UInt8>.size
        let scalars = Swift.withUnsafeBytes(of: &v) { Array($0.bindMemory(to: UInt8.self)) }
        self.init(ucharValues: scalars, count: count)
    }

    func uchar4() -> simd_uchar4 {
        var value = simd_uchar4()
        if scalarType == .uchar, byteLength == MemoryLayout<simd_uchar4>.size {
            withUnsafeBytes { source in
                _ = Swift.withUnsafeMutableBytes(of: &value) {
                    memcpy($0.baseAddress!, source.baseAddress!, MemoryLayout<simd_uchar4>.size)
                }
            }
        }
        return value
    }
}
