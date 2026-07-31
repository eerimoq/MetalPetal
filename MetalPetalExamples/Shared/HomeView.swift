//
//  HomeView.swift
//  Shared
//
//  Created by YuAo on 2021/4/3.
//

import MetalPetal
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: SimpleImageFilterView()) {
                        Text("Simple Image Filter")
                    }
                    NavigationLink(destination: SimpleImageFilterViewMTKDriven()) {
                        Text("Simple Image Filter (MTKView driven)")
                    }
                }
                Section {
                    NavigationLink(destination: CameraFilterView()) {
                        Text("Camera")
                    }
                    NavigationLink(destination: VideoProcessorView()) {
                        Text("Video Processing")
                    }
                }
                Section {
                    NavigationLink(destination: BlendModesView()) {
                        Text("Blend Modes")
                    }
                    NavigationLink(destination: BokehEffectView()) {
                        Text("Bokeh")
                    }
                    NavigationLink(destination: CLAHEFilterView()) {
                        Text("CLAHE")
                    }
                    NavigationLink(destination: GaussianBlurFilterView()) {
                        Text("MPS Gaussian Blur")
                    }
                    NavigationLink(destination: MultilayerCompositingFilterView()) {
                        Text("Multilayer Compositing")
                    }
                }
                Section {
                    NavigationLink(destination: SketchBoardView()) {
                        Text("Sketch Board")
                    }
                    NavigationLink(destination: SceneKitSupportView()) {
                        Text("Working with SceneKit")
                    }
                    NavigationLink(destination: BouncingBallsView()) {
                        Text("Particles")
                    }
                }
            }
            .inlineNavigationBarTitle("MetalPetal Examples")
        }
    }
}
