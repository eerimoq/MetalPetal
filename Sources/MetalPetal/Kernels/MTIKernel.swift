//
//  MTIKernel.swift
//  MetalPetal
//
//  Created by YuAo on 02/07/2017.
//

import Foundation
import Metal

public protocol MTIKernelConfiguration {
    /// Identifies the configuration within a kernel's state cache. Configurations with equal identifiers
    /// share a cached kernel state, so this must incorporate everything `makeKernelState` depends on.
    var identifier: AnyHashable { get }
}

/// A kernel must be stateless.
public protocol MTIKernel: AnyObject {
    func makeKernelState(
        context: MTIContext,
        configuration: MTIKernelConfiguration?
    ) throws -> Any
}
