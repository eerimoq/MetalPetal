//
//  MTICVMetalTextureBridging.swift
//  MetalPetal
//
//  Created by Yu Ao on 2018/10/10.
//

import CoreVideo
import Foundation
import Metal

public protocol MTICVMetalTexture: NSObjectProtocol {
    var texture: MTLTexture { get }
}

public protocol MTICVMetalTextureBridging: NSObjectProtocol {
    static func makeCoreVideoMetalTextureBridge(device: MTLDevice) throws -> MTICVMetalTextureBridging

    func makeTexture(
        with imageBuffer: CVImageBuffer,
        textureDescriptor: MTLTextureDescriptor,
        planeIndex: Int
    ) throws -> MTICVMetalTexture

    func flushCache()
}
