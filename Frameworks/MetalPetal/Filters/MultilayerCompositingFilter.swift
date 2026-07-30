//
//  MultilayerCompositingFilter.swift
//  MetalPetal
//
//  Created by Yu Ao on 2019/12/4.
//

import CoreGraphics
import Foundation
import Metal

extension MTILayer.FlipOptions: Hashable {}

extension MTILayer.LayoutUnit: Hashable {}

extension MTILayer.LayoutUnit: CustomDebugStringConvertible, CustomStringConvertible {
    public var debugDescription: String {
        name
    }

    public var description: String {
        name
    }

    private var name: String {
        switch self {
        case .fractionOfBackgroundSize:
            "MTILayer.LayoutUnit.fractionOfBackgroundSize"
        case .pixel:
            "MTILayer.LayoutUnit.pixel"
        }
    }
}

public class MultilayerCompositingFilter: MTIFilter {
    public struct Layer: Hashable, Equatable {
        public var content: MTIImage
        public var contentRegion: CGRect
        public var contentFlipOptions: MTILayer.FlipOptions = []
        public var mask: MTIMask?
        public var compositingMask: MTIMask?
        public var layoutUnit: MTILayer.LayoutUnit
        public var position: CGPoint
        public var size: CGSize
        public var rotation: Float = 0
        public var opacity: Float = 1
        public var cornerRadius: MTICornerRadius = .init(0)
        public var cornerCurve: MTICornerCurve = .circular
        public var tintColor: MTIColor = .clear
        public var blendMode: MTIBlendMode = .normal

        public init(content: MTIImage) {
            self.content = content
            contentRegion = content.extent
            layoutUnit = .pixel
            size = content.size
            position = CGPoint(x: content.size.width / 2, y: content.size.height / 2)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(content)
            hasher.combine(contentRegion.origin.x)
            hasher.combine(contentRegion.origin.y)
            hasher.combine(contentRegion.size.width)
            hasher.combine(contentRegion.size.height)
            hasher.combine(contentFlipOptions)
            hasher.combine(mask)
            hasher.combine(compositingMask)
            hasher.combine(layoutUnit)
            hasher.combine(position.x)
            hasher.combine(position.y)
            hasher.combine(size.width)
            hasher.combine(size.height)
            hasher.combine(rotation)
            hasher.combine(opacity)
            hasher.combine(cornerRadius)
            hasher.combine(cornerCurve)
            hasher.combine(tintColor)
            hasher.combine(blendMode)
        }

        private func mutating(_ block: (inout Layer) -> Void) -> Layer {
            var layer = self
            block(&layer)
            return layer
        }

        public static func content(_ image: MTIImage) -> Layer {
            Layer(content: image)
        }

        public static func content(_ image: MTIImage, modifier: (inout Layer) -> Void) -> Layer {
            Layer(content: image).mutating(modifier)
        }

        public func opacity(_ value: Float) -> Layer {
            mutating { $0.opacity = value }
        }

        public func contentRegion(_ contentRegion: CGRect) -> Layer {
            mutating { $0.contentRegion = contentRegion }
        }

        public func contentFlipOptions(_ contentFlipOptions: MTILayer.FlipOptions) -> Layer {
            mutating { $0.contentFlipOptions = contentFlipOptions }
        }

        public func mask(_ mask: MTIMask?) -> Layer {
            mutating { $0.mask = mask }
        }

        public func compositingMask(_ mask: MTIMask?) -> Layer {
            mutating { $0.compositingMask = mask }
        }

        public func frame(_ rect: CGRect, layoutUnit: MTILayer.LayoutUnit) -> Layer {
            mutating {
                $0.size = rect.size
                $0.position = CGPoint(x: rect.midX, y: rect.midY)
                $0.layoutUnit = layoutUnit
            }
        }

        public func frame(center: CGPoint, size: CGSize, layoutUnit: MTILayer.LayoutUnit) -> Layer {
            mutating {
                $0.size = size
                $0.position = center
                $0.layoutUnit = layoutUnit
            }
        }

        public func rotation(_ rotation: Float) -> Layer {
            mutating { $0.rotation = rotation }
        }

        public func tintColor(_ color: MTIColor?) -> Layer {
            mutating { $0.tintColor = color ?? .clear }
        }

        public func blendMode(_ blendMode: MTIBlendMode) -> Layer {
            mutating { $0.blendMode = blendMode }
        }

        public func corner(radius: MTICornerRadius, curve: MTICornerCurve) -> Layer {
            mutating {
                $0.cornerRadius = radius
                $0.cornerCurve = curve
            }
        }

        public func cornerRadius(_ radius: MTICornerRadius) -> Layer {
            mutating { $0.cornerRadius = radius }
        }

        public func cornerRadius(_ radius: Float) -> Layer {
            mutating { $0.cornerRadius = MTICornerRadius(radius) }
        }

        public func cornerCurve(_ curve: MTICornerCurve) -> Layer {
            mutating { $0.cornerCurve = curve }
        }
    }

    public var outputPixelFormat: MTLPixelFormat {
        get {
            internalFilter.outputPixelFormat
        }
        set {
            internalFilter.outputPixelFormat = newValue
        }
    }

    public var outputImage: MTIImage? {
        internalFilter.outputImage
    }

    public var inputBackgroundImage: MTIImage? {
        get {
            internalFilter.inputBackgroundImage
        }
        set {
            internalFilter.inputBackgroundImage = newValue
        }
    }

    public var outputAlphaType: MTIAlphaType {
        get {
            internalFilter.outputAlphaType
        }
        set {
            internalFilter.outputAlphaType = newValue
        }
    }

    private var _layers: [Layer] = []

    public var layers: [Layer] {
        get {
            _layers
        }
        set {
            _layers = newValue
            internalFilter.layers = newValue.map { $0.bridgeToObjectiveC() }
        }
    }

    public var rasterSampleCount: Int {
        get {
            Int(internalFilter.rasterSampleCount)
        }
        set {
            internalFilter.rasterSampleCount = UInt(newValue)
        }
    }

    private var internalFilter = MTIMultilayerCompositingFilter()

    public init() {}
}

public extension MultilayerCompositingFilter {
    @available(
        *,
        deprecated,
        message: "Use MultilayerCompositingFilter.Layer(content:).frame(...).opacity(...)... instead."
    )
    static func makeLayer(content: MTIImage, configurator: (_ layer: inout Layer) -> Void) -> Layer {
        var layer = Layer(content: content)
        configurator(&layer)
        return layer
    }
}

private extension MultilayerCompositingFilter.Layer {
    func bridgeToObjectiveC() -> MTILayer {
        MTILayer(
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
            cornerRadius: cornerRadius,
            cornerCurve: cornerCurve,
            tintColor: tintColor,
            blendMode: blendMode
        )
    }
}

extension MultilayerCompositingFilter.Layer: CustomDebugStringConvertible, CustomStringConvertible {
    public var debugDescription: String {
        let mirror = Mirror(reflecting: self)
        let members: String = mirror.children
            .reduce("") { r, c in "\(r)\(c.label ?? "(null)") = \(c.value); " }
        return "<MultilayerCompositingFilter.Layer> { \(members)}"
    }

    public var description: String {
        debugDescription
    }
}
