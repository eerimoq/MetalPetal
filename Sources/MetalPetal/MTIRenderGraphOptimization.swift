//
//  MTIRenderGraphOptimization.swift
//  MetalPetal
//

import Foundation

public final class MTIRenderGraphNode {
    public var inputs: [MTIRenderGraphNode]?
    public var image: MTIImage?
    fileprivate var outputs = Set<ObjectIdentifier>()

    public init() {}

    public var uniqueDependentCount: Int {
        outputs.count
    }
}

public final class MTIRenderGraphOptimizer {
    public init() {}

    private static func node(
        for image: MTIImage,
        dependent: MTIRenderGraphNode,
        nodeTable: NSMapTable<MTIImage, MTIRenderGraphNode>
    ) -> MTIRenderGraphNode {
        var node = nodeTable.object(forKey: image)
        if node == nil {
            let newNode = MTIRenderGraphNode()
            nodeTable.setObject(newNode, forKey: image)
            newNode.image = image
            var inputs: [MTIRenderGraphNode] = []
            for img in image.promise.dependencies {
                inputs.append(self.node(for: img, dependent: newNode, nodeTable: nodeTable))
            }
            newNode.inputs = inputs
            node = newNode
        }
        if let dependentImage = dependent.image {
            node!.outputs.insert(ObjectIdentifier(dependentImage.promise))
        }
        return node!
    }

    private static func performOptimization(
        on node: MTIRenderGraphNode,
        promiseTable: NSMapTable<AnyObject, AnyObject>
    ) -> Bool {
        guard node.image?.cachePolicy == .transient else {
            return false
        }
        var optimized = false
        for inputNode in node.inputs ?? [] where performOptimization(
            on: inputNode,
            promiseTable: promiseTable
        ) {
            optimized = true
        }
        if let promise = promiseTable.object(forKey: node.image!.promise) as? MTIImagePromise {
            if !(node.image!.promise === promise) {
                node.image = MTIImage(
                    promise: promise,
                    samplerDescriptor: node.image!.samplerDescriptor,
                    cachePolicy: node.image!.cachePolicy
                )
            }
        } else {
            let orgPromise = node.image!.promise
            MTIColorMatrixRenderGraphNodeOptimize(node)
            MTIMultilayerCompositingRenderGraphNodeOptimize(node)
            promiseTable.setObject(node.image!.promise, forKey: orgPromise)
            if !(node.image!.promise === orgPromise) {
                optimized = true
            }
        }
        return optimized
    }

    private static func generateOptimizedImage(
        for node: MTIRenderGraphNode,
        promiseTable: NSMapTable<AnyObject, AnyObject>
    ) -> MTIImage {
        if (node.inputs?.count ?? 0) == 0 || node.image!.cachePolicy != .transient {
            return node.image!
        }
        var dependencies: [MTIImage] = []
        for inputNode in node.inputs ?? [] {
            dependencies.append(generateOptimizedImage(for: inputNode, promiseTable: promiseTable))
        }
        var promise = promiseTable.object(forKey: node.image!.promise) as? MTIImagePromise
        if promise == nil {
            promise = node.image!.promise.updatingDependencies(dependencies)
            promiseTable.setObject(promise!, forKey: node.image!.promise)
        }
        return MTIImage(
            promise: promise!,
            samplerDescriptor: node.image!.samplerDescriptor,
            cachePolicy: node.image!.cachePolicy
        )
    }

    public static func promiseByOptimizingRenderGraph(of promise: MTIImagePromise) -> MTIImagePromise {
        let table = NSMapTable<MTIImage, MTIRenderGraphNode>(
            keyOptions: [.strongMemory, .objectPointerPersonality],
            valueOptions: [.strongMemory]
        )
        // Build nodes graph
        let rootNode = MTIRenderGraphNode()
        rootNode.image = MTIImage(promise: promise)
        var inputs: [MTIRenderGraphNode] = []
        for image in promise.dependencies {
            inputs.append(node(for: image, dependent: rootNode, nodeTable: table))
        }
        rootNode.inputs = inputs
        // Optimize render graph
        let promiseTable = NSMapTable<AnyObject, AnyObject>(
            keyOptions: [.strongMemory, .objectPointerPersonality],
            valueOptions: [.strongMemory]
        )
        let optimized = performOptimization(on: rootNode, promiseTable: promiseTable)
        if optimized {
            // Create merged promise
            let generationTable = NSMapTable<AnyObject, AnyObject>(
                keyOptions: [.strongMemory, .objectPointerPersonality],
                valueOptions: [.strongMemory]
            )
            return generateOptimizedImage(for: rootNode, promiseTable: generationTable).promise
        } else {
            return promise
        }
    }
}

extension MTIImageRenderingRecipe {
    var colorMatrix: MTIColorMatrix {
        var matrix = MTIColorMatrix.identity
        if renderCommands.count == 1 {
            if case let .data(data) = renderCommands[0].parameters[filterColorMatrixParameterKey],
               data.count == MemoryLayout<MTIColorMatrix>.size
            {
                _ = withUnsafeMutableBytes(of: &matrix) { dst in
                    data.copyBytes(to: dst.bindMemory(to: UInt8.self))
                }
            }
        }
        return matrix
    }
}

func MTIColorMatrixRenderGraphNodeOptimize(_ node: MTIRenderGraphNode) {
    guard (node.inputs?.count ?? 0) == 1, let v = node.image?.promise as? MTIImageRenderingPromise else {
        return
    }
    let recipe = v.recipe
    let lastNode = node.inputs![0]
    guard let lastImage = lastNode.image else {
        return
    }
    guard let command = recipe.renderCommands.first else {
        return
    }
    guard recipe.renderCommands.count == 1,
          lastNode.uniqueDependentCount == 1,
          command.kernel === MTIColorMatrixFilter.kernel(),
          let lastPromise = lastImage.promise as? MTIImageRenderingPromise
    else {
        return
    }
    var colorMatrix = recipe.colorMatrix
    guard let lastCommand = lastPromise.recipe.renderCommands.first,
          lastPromise.recipe.renderCommands.count == 1,
          lastImage.cachePolicy == .transient,
          (lastCommand.geometry as? MTIVertices) == MTIVertices.fullViewportSquare,
          lastPromise.recipe.outputDescriptors == recipe.outputDescriptors,
          lastCommand.kernel === MTIColorMatrixFilter.kernel()
    else {
        return
    }
    colorMatrix = lastPromise.recipe.colorMatrix.concat(with: colorMatrix)
    let data = withUnsafeBytes(of: &colorMatrix) { Data($0) }
    let r = MTIImageRenderingRecipe(
        renderCommands: [MTIRenderCommand(
            kernel: command.kernel,
            geometry: command.geometry,
            images: lastPromise.dependencies,
            parameters: [filterColorMatrixParameterKey: .data(data)]
        )],
        rasterSampleCount: max(recipe.rasterSampleCount, lastPromise.recipe.rasterSampleCount),
        outputDescriptors: recipe.outputDescriptors
    )
    let promise = MTIImageRenderingPromise(imageRenderingRecipe: r, outputIndex: 0)
    node.inputs = lastNode.inputs
    node.image = MTIImage(
        promise: promise,
        samplerDescriptor: node.image!.samplerDescriptor,
        cachePolicy: node.image!.cachePolicy
    )
}
