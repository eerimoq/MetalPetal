//
//  MTIKernel.swift
//  MetalPetal
//
//  Created by YuAo on 02/07/2017.
//

import Foundation
import Metal

public protocol MTIKernelConfiguration: NSObjectProtocol, NSCopying {
    var identifier: NSCopying { get }
}

/// A kernel must be stateless.
public protocol MTIKernel: NSObjectProtocol {
    func makeKernelState(
        context: MTIContext,
        configuration: MTIKernelConfiguration?
    ) throws -> Any
}
