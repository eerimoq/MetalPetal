//
//  PublicInitializerTests.swift
//  MetalPetal
//

import CoreGraphics
import Metal
import MetalPetal
import Testing

@Suite("Public API reachability")
struct PublicInitializerTests {
    @Test func filtersAreDefaultConstructibleFromOutsideTheModule() {
        let filters: [any MTIFilter] = [
            MTIBlendWithMaskFilter(),
            MTIBrightnessFilter(),
            MTIBulgeDistortionFilter(),
            MTICLAHEFilter(),
            MTIChromaKeyBlendFilter(),
            MTIColorHalftoneFilter(),
            MTIColorInvertFilter(),
            MTIColorLookupFilter(),
            MTIColorMatrixFilter(),
            MTIContrastFilter(),
            MTICropFilter(),
            MTIDotScreenFilter(),
            MTIExposureFilter(),
            MTIHexagonalBokehBlurFilter(),
            MTIHistogramDisplayFilter(),
            MTIITUR709RGBToLinearRGBFilter(),
            MTIITUR709RGBToSRGBFilter(),
            MTIAppleLogToLinearRGBFilter(),
            MTIAppleLogToSRGBFilter(),
            MTILinearToSRGBToneCurveFilter(),
            MTIMPSBoxBlurFilter(),
            MTIMPSDefinitionFilter(),
            MTIMPSGaussianBlurFilter(),
            MTIMPSHistogramFilter(),
            MTIMultilayerCompositingFilter(),
            MTIOpacityFilter(),
            MTIPinchDistortionFilter(),
            MTIPixellateFilter(),
            MTIPremultiplyAlphaFilter(),
            MTIRGBColorSpaceConversionFilter(),
            MTIRGBToneCurveFilter(),
            MTIRoundCornerFilter(),
            MTISRGBToneCurveToLinearFilter(),
            MTISaturationFilter(),
            MTITransformFilter(),
            MTITwirlDistortionFilter(),
            MTIUnpremultiplyAlphaFilter(),
            MTIVibranceFilter(),
        ]
        #expect(filters.count == 38)
        for filter in filters {
            #expect(filter.outputImage == nil)
        }
    }

    @Test func supportingTypesAreDefaultConstructibleFromOutsideTheModule() {
        _ = MTIUnaryImageRenderingFilter()
        _ = MTIMultilayerCompositeKernel()
        _ = MTIRenderGraphNode()
        _ = MTIRenderGraphOptimizer()
        _ = MTIContextOptions()
    }

    @Test func commonPublicAPIIsReachableFromOutsideTheModule() {
        let image = MTIImage.white
        #expect(image.size == CGSize(width: 1, height: 1))
        #expect(image == image)
        #expect(image.withCachePolicy(.persistent).cachePolicy == .persistent)
        let mask = MTIMask(content: image)
        #expect(mask.content == image)
        #expect(MTISamplerDescriptor.default == MTISamplerDescriptor.default)
        let descriptor = MTIRenderPassOutputDescriptor(
            dimensions: MTITextureDimensions(width: 1, height: 1, depth: 1),
            pixelFormat: .bgra8Unorm
        )
        #expect(descriptor == descriptor)
        #expect(MTIFunctionDescriptor(name: "passthrough") == MTIFunctionDescriptor(name: "passthrough"))
        #expect(MTIVector(values: [1, 2, 3, 4] as [Float]) == MTIVector(values: [1, 2, 3, 4] as [Float]))
        var layer = MultilayerCompositingFilter.Layer(content: image)
        layer.opacity = 0.5
        #expect(layer == layer)
    }

    @Test func valueTypeSignaturesAreStableForConsumers() {
        let floats: [Float] = [1, 2, 3, 4]
        let fromPointer = floats.withUnsafeBufferPointer {
            MTIVector(floatValues: $0.baseAddress!, count: floats.count)
        }
        #expect(fromPointer.count == 4)
        #expect(fromPointer.scalarType == .float)
        #expect(fromPointer.byteLength == 4 * MemoryLayout<Float>.stride)
        #expect(fromPointer == MTIVector(values: floats))
        let firstScalar: Float = fromPointer.withUnsafeBytes { $0.load(as: Float.self) }
        #expect(firstScalar == 1)
        #expect(MTIVector(value: CGPoint(x: 1, y: 2)).cgPointValue == CGPoint(x: 1, y: 2))
        #expect(MTIVector(value: CGSize(width: 3, height: 4)).cgSizeValue == CGSize(width: 3, height: 4))
        #expect(
            MTIVector(value: CGRect(x: 1, y: 2, width: 3, height: 4)).cgRectValue
                == CGRect(x: 1, y: 2, width: 3, height: 4)
        )
        #expect(MTIVector(value: SIMD2<Float>(5, 6)).float2Value == SIMD2<Float>(5, 6))
    }

    @Test func countsAndDimensionsAreIntForConsumers() throws {
        let dimensions = MTITextureDimensions(width: 4, height: 3, depth: 1)
        #expect(dimensions.width == 4)
        #expect(dimensions.height == 3)
        #expect(dimensions.depth == 1)
        #expect(MTITextureDimensions(width: 4, height: 3) == dimensions)
        #expect(MTITextureDimensions(cgSize: CGSize(width: 4, height: 3)) == dimensions)
        let descriptor = MTITextureDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 4,
            height: 3,
            mipmapped: false,
            usage: .shaderRead
        )
        #expect(descriptor.width == 4)
        #expect(descriptor.height == 3)
        let buffer = try #require(MTIDataBuffer(length: 16, options: []))
        #expect(buffer.length == 16)
        buffer.unsafeAccess { (_: UnsafeMutableRawPointer, length: Int) in
            #expect(length == 16)
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.rasterSampleCount = 4
        #expect(filter.rasterSampleCount == 4)
    }
}
