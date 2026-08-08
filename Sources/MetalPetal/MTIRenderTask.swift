//
//  MTIRenderTask.swift
//  MetalPetal
//

import Foundation
import Metal

/// Represents a GPU render task - i.e., commands in a command buffer.
public struct MTIRenderTask {
    private let commandBuffer: MTLCommandBuffer

    public init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
    }

    /// Status of the underlying command buffer.
    public var commandBufferStatus: MTLCommandBufferStatus {
        commandBuffer.status
    }

    /// Synchronously blocks execution until the task either completes or fails (with error).
    public func waitUntilCompleted() {
        commandBuffer.waitUntilCompleted()
    }

    /// If an error occurred during execution, the NSError may contain more details about the problem.
    public var error: Error? {
        commandBuffer.error
    }
}
