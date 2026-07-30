//
//  MTIFunctionArgumentsEncoder.swift
//  MetalPetal
//
//  Created by YuAo on 2020/7/11.
//

import Foundation
import Metal

public protocol MTIFunctionArgumentEncodingProxy: AnyObject {
    func encodeBytes(_ bytes: UnsafeRawPointer, length: UInt)
}

public protocol MTIFunctionArgumentEncoding {
    static func encodeValue(
        _ value: Any,
        argument: MTLArgument,
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
            NSException(
                name: .internalInconsistencyException,
                reason: "Unsupported command encoder.",
                userInfo: nil
            ).raise()
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
            NSException(
                name: .internalInconsistencyException,
                reason: "Unsupported command encoder.",
                userInfo: nil
            ).raise()
        }
    default:
        break
    }
}

private final class MTIFunctionArgumentEncodingProxyImplementation: MTIFunctionArgumentEncodingProxy {
    private var encoder: MTLCommandEncoder?
    private var argument: MTLArgument?
    private let functionType: MTLFunctionType
    private(set) var used = false
    private(set) var error: Error?

    init(encoder: MTLCommandEncoder, functionType: MTLFunctionType, argument: MTLArgument) {
        self.encoder = encoder
        self.functionType = functionType
        self.argument = argument
    }

    func encodeBytes(_ bytes: UnsafeRawPointer, length: UInt) {
        assert(encoder != nil, "An encoding proxy can only encode/reportError once.")
        guard let encoder, let argument else {
            return
        }
        if Int(length) != argument.bufferDataSize {
            error = _MTIErrorCreate(
                .parameterDataSizeMismatch,
                "MTIErrorParameterDataSizeMismatch",
                ["Argument": argument]
            )
            used = true
        } else {
            MTIArgumentsEncoderEncodeBytes(functionType, encoder, bytes, Int(length), argument.index)
            used = true
        }
        self.encoder = nil
        self.argument = nil
    }

    func invalidate() {
        encoder = nil
        argument = nil
    }
}

public enum MTIFunctionArgumentsEncoder {
    public static func encode(
        _ arguments: [MTLArgument],
        values parameters: [String: Any],
        functionType: MTLFunctionType,
        encoder: MTLCommandEncoder
    ) throws {
        for argument in arguments {
            guard argument.type == .buffer else {
                continue
            }
            guard let value = parameters[argument.name] else {
                continue
            }
            if let number = value as? NSNumber {
                switch argument.bufferDataType {
                case .bool:
                    var b = number.boolValue
                    assert(MemoryLayout.size(ofValue: b) == argument.bufferDataSize)
                    withUnsafeBytes(of: &b) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                case .int:
                    var i = number.int32Value
                    assert(MemoryLayout.size(ofValue: i) == argument.bufferDataSize)
                    withUnsafeBytes(of: &i) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                case .uint:
                    var i = number.uint32Value
                    assert(MemoryLayout.size(ofValue: i) == argument.bufferDataSize)
                    withUnsafeBytes(of: &i) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                case .char:
                    var c = number.int8Value
                    assert(MemoryLayout.size(ofValue: c) == argument.bufferDataSize)
                    withUnsafeBytes(of: &c) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                case .uchar:
                    var c = number.uint8Value
                    assert(MemoryLayout.size(ofValue: c) == argument.bufferDataSize)
                    withUnsafeBytes(of: &c) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                case .short:
                    var s = number.int16Value
                    assert(MemoryLayout.size(ofValue: s) == argument.bufferDataSize)
                    withUnsafeBytes(of: &s) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                case .ushort:
                    var s = number.uint16Value
                    assert(MemoryLayout.size(ofValue: s) == argument.bufferDataSize)
                    withUnsafeBytes(of: &s) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                case .float:
                    var f = number.floatValue
                    assert(MemoryLayout.size(ofValue: f) == argument.bufferDataSize)
                    withUnsafeBytes(of: &f) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                case .half:
                    var h = Float16(number.floatValue)
                    assert(MemoryLayout.size(ofValue: h) == argument.bufferDataSize)
                    withUnsafeBytes(of: &h) {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            $0.baseAddress!,
                            $0.count,
                            argument.index
                        )
                    }
                default:
                    throw _MTIErrorCreate(
                        .parameterDataTypeMismatch,
                        "MTIErrorParameterDataTypeMismatch",
                        ["Argument": argument, "Value": value]
                    )
                }
            } else if let nsValue = value as? NSValue {
                var size = 0
                NSGetSizeAndAlignment(nsValue.objCType, &size, nil)
                let valuePtr = malloc(size)!
                defer { free(valuePtr) }
                nsValue.getValue(valuePtr, size: size)
                guard argument.bufferDataSize == size else {
                    throw _MTIErrorCreate(
                        .parameterDataSizeMismatch,
                        "MTIErrorParameterDataSizeMismatch",
                        ["Argument": argument, "Value": value]
                    )
                }
                MTIArgumentsEncoderEncodeBytes(functionType, encoder, valuePtr, size, argument.index)
            } else if let data = value as? Data {
                data.withUnsafeBytes { rawBuffer in
                    if let baseAddress = rawBuffer.baseAddress {
                        MTIArgumentsEncoderEncodeBytes(
                            functionType,
                            encoder,
                            baseAddress,
                            rawBuffer.count,
                            argument.index
                        )
                    }
                }
            } else if let vector = value as? MTIVector {
                MTIArgumentsEncoderEncodeBytes(
                    functionType,
                    encoder,
                    vector.bytes(),
                    Int(vector.byteLength),
                    argument.index
                )
            } else if let dataBuffer = value as? MTIDataBuffer {
                if let buffer = dataBuffer.buffer(for: encoder.device) {
                    MTIArgumentsEncoderEncodeBuffer(functionType, encoder, buffer, argument.index)
                }
            } else {
                let proxy = MTIFunctionArgumentEncodingProxyImplementation(
                    encoder: encoder,
                    functionType: functionType,
                    argument: argument
                )
                try MTISIMDArgumentEncoder.encodeValue(value, argument: argument, proxy: proxy)
                if let error = proxy.error {
                    throw error
                }
                if !proxy.used {
                    proxy.invalidate()
                    throw _MTIErrorCreate(
                        .unsupportedParameterType,
                        "MTIErrorUnsupportedParameterType",
                        ["Argument": argument, "Value": value]
                    )
                }
            }
        }
    }
}
