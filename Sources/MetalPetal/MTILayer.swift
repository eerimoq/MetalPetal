//
//  MTILayer.swift
//  MetalPetal
//

import CoreGraphics
import Foundation

/// A MTILayer represents a compositing layer for MTIMultilayerCompositingFilter. MTILayers use a UIKit like
/// coordinate system.
public final class MTILayer {
    public enum LayoutUnit: Int {
        case pixel
        case fractionOfBackgroundSize
    }

    public struct FlipOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let donotFlip: FlipOptions = []
        public static let flipVertically = FlipOptions(rawValue: 1 << 0)
        public static let flipHorizontally = FlipOptions(rawValue: 1 << 1)
    }

    public let content: MTIImage
    public let contentRegion: CGRect // pixel
    public let contentFlipOptions: FlipOptions
    /// A mask that applies to the `content` of the layer. This mask is resized and aligned with the layer.
    public let mask: MTIMask?
    /// A mask that applies to the `content` of the layer. This mask is resized and aligned with the
    /// background.
    public let compositingMask: MTIMask?
    public let layoutUnit: LayoutUnit
    public let position: CGPoint
    public let size: CGSize
    public let rotation: Float // rad
    public let opacity: Float
    public let cornerRadius: MTICornerRadius
    public let cornerCurve: MTICornerCurve
    /// Tint the content to with the color. If the tintColor's alpha is zero original content is rendered.
    public let tintColor: MTIColor
    public let blendMode: MTIBlendMode

    public init(content: MTIImage,
                contentRegion: CGRect,
                contentFlipOptions: FlipOptions,
                mask: MTIMask?,
                compositingMask: MTIMask?,
                layoutUnit: LayoutUnit,
                position: CGPoint,
                size: CGSize,
                rotation: Float,
                opacity: Float,
                cornerRadius: MTICornerRadius,
                cornerCurve: MTICornerCurve,
                tintColor: MTIColor,
                blendMode: MTIBlendMode)
    {
        self.content = content
        self.contentRegion = contentRegion
        self.contentFlipOptions = contentFlipOptions
        self.mask = mask
        self.compositingMask = compositingMask
        self.layoutUnit = layoutUnit
        self.position = position
        self.size = size
        self.rotation = rotation
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.cornerCurve = cornerCurve
        self.tintColor = tintColor
        self.blendMode = blendMode
    }

    public convenience init(
        content: MTIImage,
        layoutUnit: LayoutUnit,
        position: CGPoint,
        size: CGSize,
        rotation: Float,
        opacity: Float,
        blendMode: MTIBlendMode
    ) {
        self.init(
            content: content,
            contentRegion: content.extent,
            contentFlipOptions: .donotFlip,
            compositingMask: nil,
            layoutUnit: layoutUnit,
            position: position,
            size: size,
            rotation: rotation,
            opacity: opacity,
            blendMode: blendMode
        )
    }

    public convenience init(
        content: MTIImage,
        contentRegion: CGRect,
        compositingMask: MTIMask?,
        layoutUnit: LayoutUnit,
        position: CGPoint,
        size: CGSize,
        rotation: Float,
        opacity: Float,
        blendMode: MTIBlendMode
    ) {
        self.init(
            content: content,
            contentRegion: contentRegion,
            contentFlipOptions: .donotFlip,
            compositingMask: compositingMask,
            layoutUnit: layoutUnit,
            position: position,
            size: size,
            rotation: rotation,
            opacity: opacity,
            blendMode: blendMode
        )
    }

    public convenience init(
        content: MTIImage,
        contentRegion: CGRect,
        contentFlipOptions: FlipOptions,
        compositingMask: MTIMask?,
        layoutUnit: LayoutUnit,
        position: CGPoint,
        size: CGSize,
        rotation: Float,
        opacity: Float,
        blendMode: MTIBlendMode
    ) {
        self.init(
            content: content,
            contentRegion: contentRegion,
            contentFlipOptions: contentFlipOptions,
            compositingMask: compositingMask,
            layoutUnit: layoutUnit,
            position: position,
            size: size,
            rotation: rotation,
            opacity: opacity,
            tintColor: MTIColor.clear,
            blendMode: blendMode
        )
    }

    public convenience init(
        content: MTIImage,
        contentRegion: CGRect,
        contentFlipOptions: FlipOptions,
        compositingMask: MTIMask?,
        layoutUnit: LayoutUnit,
        position: CGPoint,
        size: CGSize,
        rotation: Float,
        opacity: Float,
        tintColor: MTIColor,
        blendMode: MTIBlendMode
    ) {
        self.init(
            content: content,
            contentRegion: contentRegion,
            contentFlipOptions: contentFlipOptions,
            mask: nil,
            compositingMask: compositingMask,
            layoutUnit: layoutUnit,
            position: position,
            size: size,
            rotation: rotation,
            opacity: opacity,
            tintColor: tintColor,
            blendMode: blendMode
        )
    }

    public convenience init(
        content: MTIImage,
        contentRegion: CGRect,
        contentFlipOptions: FlipOptions,
        mask: MTIMask?,
        compositingMask: MTIMask?,
        layoutUnit: LayoutUnit,
        position: CGPoint,
        size: CGSize,
        rotation: Float,
        opacity: Float,
        tintColor: MTIColor,
        blendMode: MTIBlendMode
    ) {
        self.init(
            content: content,
            contentRegion: contentRegion,
            contentFlipOptions: contentFlipOptions,
            mask: mask,
            compositingMask: compositingMask,
            layoutUnit: layoutUnit,
            position: position,
            size: size,
            rotation: rotation,
            opacity: opacity,
            cornerRadius: MTICornerRadius(0),
            cornerCurve: .circular,
            tintColor: tintColor,
            blendMode: blendMode
        )
    }

    public func sizeInPixel(forBackgroundSize backgroundSize: CGSize) -> CGSize {
        switch layoutUnit {
        case .pixel:
            size
        case .fractionOfBackgroundSize:
            CGSize(width: backgroundSize.width * size.width, height: backgroundSize.height * size.height)
        }
    }

    public func positionInPixel(forBackgroundSize backgroundSize: CGSize) -> CGPoint {
        switch layoutUnit {
        case .pixel:
            position
        case .fractionOfBackgroundSize:
            CGPoint(x: backgroundSize.width * position.x, y: backgroundSize.height * position.y)
        }
    }
}
