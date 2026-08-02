//
//  MTIFunctionArgumentsEncoder.swift
//  MetalPetal
//
//  Created by YuAo on 2020/7/11.
//

import Foundation
import Metal

private func argumentsEncoderEncodeBytes(
    _ functionType: MTLFunctionType,
    _ encoder: MTLCommandEncoder,
    _ bytes: UnsafeRawPointer,
    _ length: Int,
    _ index: Int
) {
    switch functionType {
    case .fragment:
        (encoder as! MTLRenderCommandEncoder).setFragmentBytes(bytes, length: length, index: index)
    case .vertex:
        (encoder as! MTLRenderCommandEncoder).setVertexBytes(bytes, length: length, index: index)
    case .kernel:
        if let computeEncoder = encoder as? MTLComputeCommandEncoder {
            computeEncoder.setBytes(bytes, length: length, index: index)
        } else if let renderEncoder = encoder as? MTLRenderCommandEncoder {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            renderEncoder.setTileBytes(bytes, length: length, index: index)
            #endif
        } else {
            preconditionFailure("Unsupported command encoder.")
        }
    default:
        break
    }
}

private func argumentsEncoderEncodeBuffer(
    _ functionType: MTLFunctionType,
    _ encoder: MTLCommandEncoder,
    _ buffer: MTLBuffer,
    _ index: Int
) {
    switch functionType {
    case .fragment:
        (encoder as! MTLRenderCommandEncoder).setFragmentBuffer(buffer, offset: 0, index: index)
    case .vertex:
        (encoder as! MTLRenderCommandEncoder).setVertexBuffer(buffer, offset: 0, index: index)
    case .kernel:
        if let computeEncoder = encoder as? MTLComputeCommandEncoder {
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
        } else if let renderEncoder = encoder as? MTLRenderCommandEncoder {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            renderEncoder.setTileBuffer(buffer, offset: 0, index: index)
            #endif
        } else {
            preconditionFailure("Unsupported command encoder.")
        }
    default:
        break
    }
}

private let dataTypeMismatchError = MTIError.parameterDataTypeMismatch
private let dataSizeMismatchError = MTIError.parameterDataSizeMismatch

public func MTIEncodeArguments(
    _ bindings: [any MTLBinding],
    values parameters: [String: MTIFunctionArgumentValue],
    functionType: MTLFunctionType,
    encoder: MTLCommandEncoder
) throws {
    for binding in bindings {
        guard binding.type == .buffer, let binding = binding as? any MTLBufferBinding else {
            continue
        }
        guard let value = parameters[binding.name] else {
            continue
        }
        func encodeScalar(_ scalar: some Any) {
            var scalar = scalar
            withUnsafeBytes(of: &scalar) {
                encodeBytes($0)
            }
        }
        func encodeBytes(_ bytes: UnsafeRawBufferPointer) {
            argumentsEncoderEncodeBytes(
                functionType,
                encoder,
                bytes.baseAddress!,
                bytes.count,
                binding.index
            )
        }
        switch value {
        case let .bool(value):
            guard binding.bufferDataType == .bool else {
                throw dataTypeMismatchError
            }
            encodeScalar(value)
        case let .int(value):
            switch binding.bufferDataType {
            case .int:
                encodeScalar(value)
            case .short:
                encodeScalar(Int16(truncatingIfNeeded: value))
            case .char:
                encodeScalar(Int8(truncatingIfNeeded: value))
            default:
                throw dataTypeMismatchError
            }
        case let .uint(value):
            switch binding.bufferDataType {
            case .uint:
                encodeScalar(value)
            case .ushort:
                encodeScalar(UInt16(truncatingIfNeeded: value))
            case .uchar:
                encodeScalar(UInt8(truncatingIfNeeded: value))
            default:
                throw dataTypeMismatchError
            }
        case let .float(value):
            switch binding.bufferDataType {
            case .float:
                encodeScalar(value)
            #if !((os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64))
            case .half:
                encodeScalar(Float16(value))
            #endif
            default:
                throw dataTypeMismatchError
            }
        case let .simd(value):
            guard binding.bufferDataType == value.dataType else {
                throw dataTypeMismatchError
            }
            try value.withUnsafeBytes { bytes in
                guard bytes.count == binding.bufferDataSize else {
                    throw dataSizeMismatchError
                }
                encodeBytes(bytes)
            }
        case let .vector(value):
            value.withUnsafeBytes { bytes in
                encodeBytes(bytes)
            }
        case let .data(value):
            value.withUnsafeBytes { bytes in
                encodeBytes(bytes)
            }
        case let .dataBuffer(value):
            if let buffer = value.buffer(for: encoder.device) {
                argumentsEncoderEncodeBuffer(functionType, encoder, buffer, binding.index)
            }
        }
    }
}
