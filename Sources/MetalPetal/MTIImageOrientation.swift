//
//  MTIImageOrientation.swift
//  MetalPetal
//
//  Created by Yu Ao on 16/10/2017.
//

import Foundation
import ImageIO

// https://developer.apple.com/documentation/uikit/uiimageorientation?language=objc

public enum MTIImageOrientation: Int {
    case unknown = 0
    case up = 1
    case upMirrored = 2
    case down = 3
    case downMirrored = 4
    case leftMirrored = 5
    case right = 6
    case rightMirrored = 7
    case left = 8
}

public extension MTIImageOrientation {
    init(cgImagePropertyOrientation orientation: CGImagePropertyOrientation) {
        switch orientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .unknown
        }
    }
}
