//
//  MTIImagePromiseDebug.swift
//  MetalPetal
//

import CoreGraphics
import Foundation
import QuartzCore

#if canImport(UIKit)
import UIKit

private typealias MTIFont = UIFont
#else
import AppKit

private typealias MTIFont = NSFont
#endif

public enum MTIImagePromiseType: Int {
    case source
    case processor
}

public func MTIImagePromiseDebugIdentifierForObject(_ object: Any) -> String {
    let pointer = Unmanaged.passUnretained(object as AnyObject).toOpaque()
    let string = String(format: "%p", Int(bitPattern: pointer))
    return String(string.dropFirst(2))
}

public struct MTIImagePromiseDebugInfo {
    public let identifier: String
    public let type: MTIImagePromiseType
    public let title: String
    public let content: Any?
    private let dimensions: MTITextureDimensions
    private let alphaType: MTIAlphaType

    public init(promise: MTIImagePromise, type: MTIImagePromiseType, content: Any?) {
        identifier = MTIImagePromiseDebugIdentifierForObject(promise)
        self.type = type
        self.content = content
        title = String(describing: Swift.type(of: promise))
        dimensions = promise.dimensions
        alphaType = promise.alphaType
    }

    public var description: String {
        "<\(Swift.type(of: self)): \(String(describing: content))>"
    }

    private func layerRepresentation() -> CALayer {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let contentPadding: CGFloat = 10
        let foregroundColor = CGColor(colorSpace: colorSpace, components: [0.17, 0.17, 0.17, 1.0])!
        let backgroundColor: CGColor
        let borderColor: CGColor
        switch type {
        case .source:
            backgroundColor = CGColor(colorSpace: colorSpace, components: [0.93, 0.94, 0.95, 1.0])!
            borderColor = CGColor(colorSpace: colorSpace, components: [0.74, 0.76, 0.78, 1.0])!
        case .processor:
            backgroundColor = CGColor(colorSpace: colorSpace, components: [1.0, 0.8, 0.0, 1.0])!
            borderColor = CGColor(colorSpace: colorSpace, components: [1.0, 0.66, 0.0, 1.0])!
        }
        let baseLayer = CALayer()
        baseLayer.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        baseLayer.borderWidth = 2
        baseLayer.cornerRadius = 5
        baseLayer.backgroundColor = backgroundColor
        baseLayer.borderColor = borderColor
        baseLayer.masksToBounds = true
        let titleBackgroundLayer = CALayer()
        titleBackgroundLayer.frame = CGRect(x: 0, y: 0, width: baseLayer.bounds.size.width, height: 24)
        titleBackgroundLayer.backgroundColor = borderColor
        baseLayer.addSublayer(titleBackgroundLayer)
        let titleLayer = CATextLayer()
        titleLayer.fontSize = 12
        titleLayer.string = title
        titleLayer.foregroundColor = foregroundColor
        let titleLayerPreferredSize = titleLayer.preferredFrameSize()
        titleLayer.frame = CGRect(
            x: contentPadding,
            y: (titleBackgroundLayer.bounds.size.height - titleLayerPreferredSize.height) / 2.0,
            width: titleLayerPreferredSize.width,
            height: titleLayerPreferredSize.height
        )
        titleBackgroundLayer.addSublayer(titleLayer)
        let contentTextLayer = CATextLayer()
        contentTextLayer.fontSize = 10
        var contentString = ""
        contentString += "[\(dimensions.width)x\(dimensions.height)x\(dimensions.depth)]"
        contentString += " Alpha: \(MTIAlphaTypeGetDescription(alphaType))\n"
        contentString += "\n"
        contentString += (content as AnyObject?)?.debugDescription ?? ""
        contentTextLayer.string = contentString
        contentTextLayer.foregroundColor = foregroundColor
        baseLayer.addSublayer(contentTextLayer)
        let contentTextLayerPreferredSize = (contentString as NSString).boundingRect(
            with: CGSize(width: baseLayer.frame.size.width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: MTIFont.systemFont(ofSize: 10)],
            context: nil
        ).size
        contentTextLayer.isWrapped = true
        contentTextLayer.frame = CGRect(
            x: contentPadding,
            y: titleBackgroundLayer.frame.maxY + contentPadding,
            width: contentTextLayerPreferredSize.width,
            height: contentTextLayerPreferredSize.height
        )
        baseLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: baseLayer.frame.size.width,
            height: contentTextLayer.frame.maxY + contentPadding * 2
        )
        return baseLayer
    }

    private static func layerRepresentationOfRenderGraph(
        for promise: MTIImagePromise,
        promiseLayerTable: NSMutableDictionary
    ) -> CALayer {
        if let generatedLayer = promiseLayerTable[promise] as? CALayer {
            return generatedLayer
        }
        let container = CALayer()
        let rootLayer = promise.debugInfo.layerRepresentation()
        container.addSublayer(rootLayer)
        promiseLayerTable[promise] = rootLayer
        var x: CGFloat = 0
        let y = rootLayer.frame.maxY + 60
        var maxHeight = rootLayer.frame.maxY
        var maxWidth = rootLayer.frame.maxX
        for image in promise.dependencies where promiseLayerTable[image.promise] == nil {
            let layer = layerRepresentationOfRenderGraph(
                for: image.promise,
                promiseLayerTable: promiseLayerTable
            )
            var frame = layer.frame
            frame.origin.x = x
            frame.origin.y = y
            layer.frame = frame
            x = layer.frame.maxX + 40
            container.addSublayer(layer)
            if layer.frame.maxY > maxHeight {
                maxHeight = layer.frame.maxY
            }
            if layer.frame.maxX > maxWidth {
                maxWidth = layer.frame.maxX
            }
        }
        container.frame = CGRect(x: 0, y: 0, width: maxWidth, height: maxHeight)
        return container
    }

    private static func makeConnection(
        for promise: MTIImagePromise,
        path: CGMutablePath,
        container: CALayer,
        promiseLayerTable: NSMutableDictionary
    ) {
        guard let rootLayer = promiseLayerTable[promise] as? CALayer else {
            return
        }
        for image in promise.dependencies {
            makeConnection(
                for: image.promise,
                path: path,
                container: container,
                promiseLayerTable: promiseLayerTable
            )
            guard let layer = promiseLayerTable[image.promise] as? CALayer else { continue }
            let rootLayerFrame = rootLayer.convert(rootLayer.bounds, to: container)
            let layerFrame = layer.convert(layer.bounds, to: container)
            let fromPoint = CGPoint(x: layerFrame.midX, y: layerFrame.minY)
            var toPoint = CGPoint(x: rootLayerFrame.midX, y: rootLayerFrame.maxY)
            let direction = CGPoint(
                x: CGFloat(Int((toPoint.x - fromPoint.x) / 10.0)),
                y: CGFloat(Int((toPoint.y - fromPoint.y) / 10.0))
            )
            if direction.y > 0 {
                if direction.x > 0 {
                    toPoint = CGPoint(x: rootLayerFrame.minX, y: rootLayerFrame.midY)
                } else if direction.x < 0 {
                    toPoint = CGPoint(x: rootLayerFrame.maxX, y: rootLayerFrame.midY)
                }
            }
            path.move(to: fromPoint)
            path.addLine(to: toPoint)
            let arrowWidth: CGFloat = 4
            let arrowHeight: CGFloat = 10
            let angle = atan2(toPoint.y - fromPoint.y, toPoint.x - fromPoint.x)
            let angleAdjustment = atan2(arrowWidth, -arrowHeight)
            let distance = hypot(arrowWidth, arrowHeight)
            let arrowPointA = CGPoint(
                x: toPoint.x + cos(angle - angleAdjustment) * distance,
                y: toPoint.y + sin(angle - angleAdjustment) * distance
            )
            let arrowPointB = CGPoint(
                x: toPoint.x + cos(angle + angleAdjustment) * distance,
                y: toPoint.y + sin(angle + angleAdjustment) * distance
            )
            path.move(to: toPoint)
            path.addLine(to: arrowPointA)
            path.move(to: toPoint)
            path.addLine(to: arrowPointB)
            path.addEllipse(in: CGRect(x: fromPoint.x - 2, y: fromPoint.y - 2, width: 4, height: 4))
        }
    }

    public static func layerRepresentationOfRenderGraph(for promise: MTIImagePromise) -> CALayer {
        let promiseLayerTable = NSMutableDictionary()
        let container = layerRepresentationOfRenderGraph(for: promise, promiseLayerTable: promiseLayerTable)
        let linkLayer = CAShapeLayer()
        let path = CGMutablePath()
        makeConnection(for: promise, path: path, container: container, promiseLayerTable: promiseLayerTable)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let foregroundColor = CGColor(colorSpace: colorSpace, components: [0.20, 0.29, 0.37, 0.75])!
        linkLayer.frame = container.bounds
        linkLayer.path = path
        linkLayer.lineWidth = 2
        linkLayer.lineCap = .round
        linkLayer.lineJoin = .round
        linkLayer.strokeColor = foregroundColor
        container.addSublayer(linkLayer)
        return container
    }
}
