//
//  MTIFunctionArgumentValue.swift
//  MetalPetal
//

import Foundation
import Metal

public enum MTIFunctionArgumentValue {
    case bool(Bool)
    case int(Int32)
    case uint(UInt32)
    case float(Float)
    case simd(MTISIMDArgumentValue)
    case vector(MTIVector)
    case data(Data)
    case dataBuffer(MTIDataBuffer)
}
