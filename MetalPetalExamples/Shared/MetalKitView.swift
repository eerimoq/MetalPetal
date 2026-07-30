//
//  MetalKitView.swift
//  MetalPetalDemo
//
//  Created by YuAo on 2021/4/3.
//

import Foundation
import MetalKit
import MetalPetal
import SwiftUI

#if os(iOS)
private typealias ViewRepresentable = UIViewRepresentable
#elseif os(macOS)
private typealias ViewRepresentable = NSViewRepresentable
#endif

struct MetalKitView: ViewRepresentable {
    typealias ViewUpdater = (MTKView) -> Void
    private let viewUpdater: ViewUpdater
    private let device: MTLDevice

    init(device: MTLDevice, viewUpdater: @escaping ViewUpdater) {
        self.viewUpdater = viewUpdater
        self.device = device
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.delegate = context.coordinator
        mtkView.autoResizeDrawable = true
        mtkView.colorPixelFormat = .bgra8Unorm
        return mtkView
    }

    func updateUIView(_: MTKView, context _: Context) {}

    func makeNSView(context: Context) -> MTKView {
        makeUIView(context: context)
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        updateUIView(nsView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewUpdater: viewUpdater)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        private let viewUpdater: ViewUpdater

        init(viewUpdater: @escaping ViewUpdater) {
            self.viewUpdater = viewUpdater
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

        func draw(in view: MTKView) {
            viewUpdater(view)
        }
    }
}
