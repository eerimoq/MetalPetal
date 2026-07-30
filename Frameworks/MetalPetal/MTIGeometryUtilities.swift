//
//  MTIGeometryUtilities.swift
//  MetalPetal
//

import AVFoundation
import CoreGraphics
import Foundation

public func MTIMakeRect(aspectRatio: CGSize, fillRect boundingRect: CGRect) -> CGRect {
    let horizontalRatio = boundingRect.size.width / aspectRatio.width
    let verticalRatio = boundingRect.size.height / aspectRatio.height
    let ratio = max(horizontalRatio, verticalRatio)
    let newSize = CGSize(width: aspectRatio.width * ratio, height: aspectRatio.height * ratio)
    return CGRect(x: boundingRect.origin.x + (boundingRect.size.width - newSize.width) / 2,
                  y: boundingRect.origin.y + (boundingRect.size.height - newSize.height) / 2,
                  width: newSize.width,
                  height: newSize.height)
}

public func MTIMakeRect(aspectRatio: CGSize, insideRect boundingRect: CGRect) -> CGRect {
    AVMakeRect(aspectRatio: aspectRatio, insideRect: boundingRect)
}
