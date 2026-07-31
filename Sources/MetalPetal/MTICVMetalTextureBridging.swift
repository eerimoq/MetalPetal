//
//  MTICVMetalTextureBridging.swift
//  MetalPetal
//
//  Created by Yu Ao on 2018/10/10.
//

import CoreVideo
import Foundation
import Metal

public protocol MTICVMetalTexture: AnyObject {
    var texture: MTLTexture { get }
}

public protocol MTICVMetalTextureBridging: AnyObject {
    func makeTexture(
        with imageBuffer: CVImageBuffer,
        textureDescriptor: MTLTextureDescriptor,
        planeIndex: Int
    ) throws -> MTICVMetalTexture
    func flushCache()
}
