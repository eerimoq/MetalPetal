//
//  MTIContext.swift
//  MetalPetal
//
//  Created by YuAo on 2020/7/24.
//

import Foundation

public extension MTIContext {
    func startTaskToCreateCGImage(
        from image: MTIImage,
        colorSpace: CGColorSpace? = nil,
        completion: ((MTIRenderTask) -> Void)? = nil
    ) throws -> (image: CGImage, task: MTIRenderTask) {
        var outputCGImage: CGImage?
        let task = try startTask(
            toCreate: &outputCGImage,
            from: image,
            colorSpace: colorSpace,
            completion: completion
        )
        return (outputCGImage!, task)
    }
}
