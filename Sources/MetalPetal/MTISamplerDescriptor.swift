//
//  MTISamplerDescriptor.swift
//  MetalPetal
//
//  Created by YuAo on 29/06/2017.
//

import Foundation
import Metal

/// An immutable wrapper for MTLSamplerDescriptor.
public struct MTISamplerDescriptor: Hashable {
    private let metalSamplerDescriptor: MTLSamplerDescriptor
    private let cachedHashValue: Int

    public init(mtlSamplerDescriptor samplerDescriptor: MTLSamplerDescriptor) {
        metalSamplerDescriptor = samplerDescriptor.copy() as! MTLSamplerDescriptor
        cachedHashValue = samplerDescriptor.hash
    }

    public func makeMTLSamplerDescriptor() -> MTLSamplerDescriptor {
        metalSamplerDescriptor.copy() as! MTLSamplerDescriptor
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cachedHashValue)
    }

    public static func == (lhs: MTISamplerDescriptor, rhs: MTISamplerDescriptor) -> Bool {
        if lhs.metalSamplerDescriptor === rhs.metalSamplerDescriptor {
            return true
        }
        return lhs.metalSamplerDescriptor.isEqual(rhs.metalSamplerDescriptor)
    }

    public static let `default`: MTISamplerDescriptor = {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToZero
        samplerDescriptor.tAddressMode = .clampToZero
        return samplerDescriptor.makeMTISamplerDescriptor()
    }()

    private static func makeDefault(addressMode: MTLSamplerAddressMode) -> MTISamplerDescriptor {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = addressMode
        samplerDescriptor.tAddressMode = addressMode
        samplerDescriptor.rAddressMode = addressMode
        return samplerDescriptor.makeMTISamplerDescriptor()
    }

    private static let defaultClampToZero = makeDefault(addressMode: .clampToZero)
    private static let defaultClampToEdge = makeDefault(addressMode: .clampToEdge)
    private static let defaultRepeat = makeDefault(addressMode: .repeat)
    private static let defaultMirrorRepeat = makeDefault(addressMode: .mirrorRepeat)
    private static let defaultMirrorClampToEdge = makeDefault(addressMode: .mirrorClampToEdge)
    private static let defaultClampToBorderColor = makeDefault(addressMode: .clampToBorderColor)

    public static func defaultSamplerDescriptor(withAddressMode addressMode: MTLSamplerAddressMode)
        -> MTISamplerDescriptor
    {
        switch addressMode {
        case .mirrorRepeat:
            return defaultMirrorRepeat
        case .clampToEdge:
            return defaultClampToEdge
        case .repeat:
            return defaultRepeat
        case .clampToZero:
            return defaultClampToZero
        case .mirrorClampToEdge:
            return defaultMirrorClampToEdge
        case .clampToBorderColor:
            return defaultClampToBorderColor
        @unknown default:
            return defaultClampToZero
        }
    }
}

public extension MTLSamplerDescriptor {
    func makeMTISamplerDescriptor() -> MTISamplerDescriptor {
        MTISamplerDescriptor(mtlSamplerDescriptor: self)
    }
}
