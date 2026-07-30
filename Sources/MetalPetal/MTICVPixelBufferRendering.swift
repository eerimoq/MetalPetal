//
//  MTICVPixelBufferRendering.swift
//  MetalPetal
//
//  Created by Yu Ao on 08/04/2018.
//

import Foundation

public enum MTICVPixelBufferRenderingAPI: Int {
    case metalPetal = 1
    case coreImage = 2
}

public extension MTICVPixelBufferRenderingAPI {
    static let `default` = MTICVPixelBufferRenderingAPI.metalPetal
}

public final class MTICVPixelBufferRenderingOptions: NSObject, NSCopying {
    public let renderingAPI: MTICVPixelBufferRenderingAPI

    // An option for treating the pixel buffer data as sRGB image data. Specifying whether to create
    // the texture with an sRGB (gamma corrected) pixel format.
    public let sRGB: Bool

    public init(renderingAPI: MTICVPixelBufferRenderingAPI, sRGB: Bool) {
        self.renderingAPI = renderingAPI
        self.sRGB = sRGB
        super.init()
    }

    public func copy(with _: NSZone? = nil) -> Any {
        self
    }

    public static let `default` = MTICVPixelBufferRenderingOptions(renderingAPI: .default, sRGB: false)
}
