//
//  MTIFunctionArgumentsEncoder.swift
//  MetalPetal
//
//  Created by YuAo on 2020/7/11.
//

import Foundation
import Metal

func encodeKernelArguments(
    bindings: [any MTLBinding],
    parameters: [String: MTIFunctionArgumentValue],
    encoder: MTLComputeCommandEncoder
) throws {
    try encodeArguments(bindings: bindings,
                        parameters: parameters,
                        encodeBytes: encoder.setBytes,
                        encodeBuffer: encoder.setBuffer,
                        device: encoder.device)
}

func encodeVertexArguments(
    bindings: [any MTLBinding],
    parameters: [String: MTIFunctionArgumentValue],
    encoder: MTLRenderCommandEncoder
) throws {
    try encodeArguments(bindings: bindings,
                        parameters: parameters,
                        encodeBytes: encoder.setVertexBytes,
                        encodeBuffer: encoder.setVertexBuffer,
                        device: encoder.device)
}

func encodeFragmentArguments(
    bindings: [any MTLBinding],
    parameters: [String: MTIFunctionArgumentValue],
    encoder: MTLRenderCommandEncoder
) throws {
    try encodeArguments(bindings: bindings,
                        parameters: parameters,
                        encodeBytes: encoder.setFragmentBytes,
                        encodeBuffer: encoder.setFragmentBuffer,
                        device: encoder.device)
}

private func encodeArguments(
    bindings: [any MTLBinding],
    parameters: [String: MTIFunctionArgumentValue],
    encodeBytes: (UnsafeRawPointer, Int, Int) -> Void,
    encodeBuffer: (MTLBuffer, Int, Int) -> Void,
    device: MTLDevice
) throws {
    for binding in bindings {
        guard binding.type == .buffer, let binding = binding as? any MTLBufferBinding else {
            continue
        }
        guard let value = parameters[binding.name] else {
            continue
        }
        func encode(scalar: Any) {
            var scalar = scalar
            withUnsafeBytes(of: &scalar) {
                encodeBytes($0.baseAddress!, $0.count, binding.index)
            }
        }
        func encode(bytes: UnsafeRawBufferPointer) {
            encodeBytes(bytes.baseAddress!, bytes.count, binding.index)
        }
        switch value {
        case let .bool(value):
            switch binding.bufferDataType {
            case .bool:
                encode(scalar: value)
            default:
                throw MTIError.parameterDataTypeMismatch
            }
        case let .int(value):
            switch binding.bufferDataType {
            case .int:
                encode(scalar: value)
            case .short:
                encode(scalar: Int16(truncatingIfNeeded: value))
            case .char:
                encode(scalar: Int8(truncatingIfNeeded: value))
            default:
                throw MTIError.parameterDataTypeMismatch
            }
        case let .uint(value):
            switch binding.bufferDataType {
            case .uint:
                encode(scalar: value)
            case .ushort:
                encode(scalar: UInt16(truncatingIfNeeded: value))
            case .uchar:
                encode(scalar: UInt8(truncatingIfNeeded: value))
            default:
                throw MTIError.parameterDataTypeMismatch
            }
        case let .float(value):
            switch binding.bufferDataType {
            case .float:
                encode(scalar: value)
            #if !((os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64))
            case .half:
                encode(scalar: Float16(value))
            #endif
            default:
                throw MTIError.parameterDataTypeMismatch
            }
        case let .simd(value):
            guard binding.bufferDataType == value.dataType else {
                throw MTIError.parameterDataTypeMismatch
            }
            value.withUnsafeBytes {
                encode(bytes: $0)
            }
        case let .data(value):
            value.withUnsafeBytes {
                encode(bytes: $0)
            }
        case let .dataBuffer(value):
            if let buffer = value.buffer(for: device) {
                encodeBuffer(buffer, 0, binding.index)
            }
        }
    }
}
