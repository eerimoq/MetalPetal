//
//  MTIImageOrientation.swift
//  MetalPetal
//
//  Created by Yu Ao on 16/10/2017.
//

import Foundation
import ImageIO

public enum MTIImageOrientation {
    case unknown
    case up
    case upMirrored
    case down
    case downMirrored
    case leftMirrored
    case right
    case rightMirrored
    case left

    init(orientation: CGImagePropertyOrientation) {
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
