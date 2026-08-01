//
//  MTIFunctionArgumentsEncoder.swift
//  MetalPetal
//
//  Created by YuAo on 2020/7/11.
//

import Foundation
import Metal

public protocol MTIFunctionArgumentEncodingProxy: AnyObject {
    func encodeBytes(_ bytes: UnsafeRawPointer, length: Int)
}

public protocol MTIFunctionArgumentEncoding {
    /// The binding is always a buffer binding: the encoder only ever encodes values into buffer
    /// arguments, and `MTLBufferBinding` is what carries `bufferDataType` and `bufferDataSize`.
    static func encodeValue(
        _ value: Any,
        binding: any MTLBufferBinding,
        proxy: MTIFunctionArgumentEncodingProxy
    ) throws
}

private func MTIArgumentsEncoderEncodeBytes(
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

private func MTIArgumentsEncoderEncodeBuffer(
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

private final class MTIFunctionArgumentEncodingProxyImplementation: MTIFunctionArgumentEncodingProxy {
    private var encoder: MTLCommandEncoder?
    private var binding: (any MTLBufferBinding)?
    private let functionType: MTLFunctionType
    private(set) var used = false
    private(set) var error: Error?

    init(encoder: MTLCommandEncoder, functionType: MTLFunctionType, binding: any MTLBufferBinding) {
        self.encoder = encoder
        self.functionType = functionType
        self.binding = binding
    }

    func encodeBytes(_ bytes: UnsafeRawPointer, length: Int) {
        guard let encoder, let binding else {
            return
        }
        if length != binding.bufferDataSize {
            error = MTIError(
                code: .parameterDataSizeMismatch,
                message: "MTIErrorParameterDataSizeMismatch"
            )
            used = true
        } else {
            MTIArgumentsEncoderEncodeBytes(functionType, encoder, bytes, length, binding.index)
            used = true
        }
        self.encoder = nil
        self.binding = nil
    }

    func invalidate() {
        encoder = nil
        binding = nil
    }
}

public enum MTIFunctionArgumentsEncoder {
    public static func encode(
        _ bindings: [any MTLBinding],
        values parameters: [String: Any],
        functionType: MTLFunctionType,
        encoder: MTLCommandEncoder
    ) throws {
        for binding in bindings {
            // Only buffer bindings carry a data type/size to encode into.
            guard binding.type == .buffer, let binding = binding as? any MTLBufferBinding else {
                continue
            }
            guard let value = parameters[binding.name] else {
                continue
            }
            /// Encodes a trivial scalar, checking it against the size the shader declared.
            func encodeScalar(_ scalar: some Any) {
                var scalar = scalar
                withUnsafeBytes(of: &scalar) {
                    MTIArgumentsEncoderEncodeBytes(
                        functionType,
                        encoder,
                        $0.baseAddress!,
                        $0.count,
                        binding.index
                    )
                }
            }
            if let number = value as? NSNumber {
                switch binding.bufferDataType {
                case .bool: encodeScalar(number.boolValue)
                case .int: encodeScalar(number.int32Value)
                case .uint: encodeScalar(number.uint32Value)
                case .char: encodeScalar(number.int8Value)
                case .uchar: encodeScalar(number.uint8Value)
                case .short: encodeScalar(number.int16Value)
                case .ushort: encodeScalar(number.uint16Value)
                case .float: encodeScalar(number.floatValue)
                #if !((os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64))
                case .half: encodeScalar(Float16(number.floatValue))
                #endif
                default:
                    throw MTIError(
                        code: .parameterDataTypeMismatch,
                        message: "MTIErrorParameterDataTypeMismatch"
                    )
                }
            } else if let nsValue = value as? NSValue {
                var size = 0
                NSGetSizeAndAlignment(nsValue.objCType, &size, nil)
                let valuePtr = malloc(size)!
                defer {
                    free(valuePtr)
                }
                nsValue.getValue(valuePtr, size: size)
                guard binding.bufferDataSize == size else {
                    throw MTIError(
                        code: .parameterDataSizeMismatch,
                        message: "MTIErrorParameterDataSizeMismatch"
                    )
                }
                MTIArgumentsEncoderEncodeBytes(functionType, encoder, valuePtr, size, binding.index)
            } else if let data = value as? Data {
                data.withUnsafeBytes { rawBuffer in
                    if let baseAddress = rawBuffer.baseAddress {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            baseAddress,
                            rawBuffer.count,
                            binding.index
                        )
                    }
                }
            } else if let vector = value as? MTIVector {
                vector.withUnsafeBytes { raw in
                    MTIArgumentsEncoderEncodeBytes(
                        functionType,
                        encoder,
                        raw.baseAddress!,
                        raw.count,
                        binding.index
                    )
                }
            } else if let dataBuffer = value as? MTIDataBuffer {
                if let buffer = dataBuffer.buffer(for: encoder.device) {
                    MTIArgumentsEncoderEncodeBuffer(functionType, encoder, buffer, binding.index)
                }
            } else {
                let proxy = MTIFunctionArgumentEncodingProxyImplementation(
                    encoder: encoder,
                    functionType: functionType,
                    binding: binding
                )
                try MTISIMDArgumentEncoder.encodeValue(value, binding: binding, proxy: proxy)
                if let error = proxy.error {
                    throw error
                }
                if !proxy.used {
                    proxy.invalidate()
                    throw MTIError(
                        code: .unsupportedParameterType,
                        message: "MTIErrorUnsupportedParameterType"
                    )
                }
            }
        }
    }
}
