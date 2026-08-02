//
//  BouncingBallsView.swift
//  MetalPetalDemo
//
//  Created by YuAo on 2021/4/4.
//

import Foundation
import MetalPetal
import SwiftUI

private class PointVertices: MTIGeometry {
    func encodeDrawCall(
        with commandEncoder: MTLRenderCommandEncoder,
        context _: MTIGeometryRenderingContext
    ) {
        commandEncoder.drawPrimitives(
            type: .point,
            vertexStart: 0,
            vertexCount: 1,
            instanceCount: BouncingBallsView.numberOfParticles
        )
    }
}

private class FrameDataBuffer: ObservableObject {
    @Published var buffer: MTIDataBuffer = FrameDataBuffer.makeBuffer()

    func reset() {
        buffer = FrameDataBuffer.makeBuffer()
    }

    private static func makeBuffer() -> MTIDataBuffer {
        var particles: [ParticleData] = []
        for _ in 0 ..< BouncingBallsView.numberOfParticles {
            particles.append(ParticleData(
                position: SIMD2<Float>(Float.random(in: 24 ... 1000), Float.random(in: 24 ... 400)),
                speed: .zero,
                size: Float.random(in: 8 ... 36)
            ))
        }
        return MTIDataBuffer(
            bytes: particles,
            length: MemoryLayout<ParticleData>.stride * BouncingBallsView.numberOfParticles,
            options: .init()
        )!
    }
}

private let computeKernel =
    MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
        name: "bouncingBallCompute",
        in: .main
    ))

private let renderKernel = MTIRenderPipelineKernel(
    vertexFunctionDescriptor: .init(name: "bouncingBallVertex", in: .main),
    fragmentFunctionDescriptor: .init(name: "bouncingBallFragment", in: .main)
)

struct BouncingBallsView: View {
    static let numberOfParticles = 1024
    @StateObject private var renderContext = try! MTIContext(device: MTLCreateSystemDefaultDevice()!)
    @StateObject private var frameDataBuffer: FrameDataBuffer = .init()

    var body: some View {
        MetalKitView(device: renderContext.device) { view in
            let computeOutput = computeKernel.apply(
                toInputImages: [],
                parameters: ["data": .dataBuffer(frameDataBuffer.buffer)],
                dispatchOptions: .init(
                    threads: MTLSize(width: 1024, height: 1, depth: 1),
                    threadgroups: MTLSize(width: 32, height: 1, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1)
                ),
                outputTextureDimensions: MTITextureDimensions(width: 1, height: 1, depth: 1),
                outputPixelFormat: .unspecified
            )
            // There's no actual image data in computeOutput. It is used to build the dependency between the
            // compute command and the render command.
            let renderCommand = MTIRenderCommand(
                kernel: renderKernel,
                geometry: PointVertices(),
                images: [computeOutput],
                parameters: ["data": .dataBuffer(frameDataBuffer.buffer)]
            )
            let output = MTIRenderCommand.images(
                byPerforming: [renderCommand],
                outputDescriptors: [MTIRenderPassOutputDescriptor(
                    dimensions: MTITextureDimensions(width: 1024, height: 1024, depth: 1),
                    pixelFormat: .unspecified,
                    clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1),
                    loadAction: .clear,
                    storeAction: .store
                )]
            )
            let request = MTIDrawableRenderingRequest(drawableProvider: view, resizingMode: .aspect)
            do {
                try renderContext.render(output[0], toDrawableWithRequest: request)
            } catch {
                print(error)
            }
        }
        .toolbar {
            Button("Reset") { [frameDataBuffer] in
                frameDataBuffer.reset()
            }
        }
        .inlineNavigationBarTitle("Particles")
    }
}
