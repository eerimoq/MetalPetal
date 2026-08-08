//
//  UtilitiesTests.swift
//
//
//  Created by YuAo on 2021/2/2.
//

import AVFoundation
import Foundation
import Metal
@testable import MetalPetal
import MetalPetalTestHelpers
import simd
import Testing

@Suite(.enabled(if: metalDeviceIsAvailable))
struct UtilitiesTests {
    static let mtiShaderLibrarySource: String = {
        let headerURL = URL(fileURLWithPath: String(#file))
            .deletingLastPathComponent()
            .appendingPathComponent("../../Sources/MetalPetal/Shaders/MTIShaderLib.h")
        return try! String(contentsOf: headerURL)
    }()

    @Test func weakToStrongTable() throws {
        class Key {}
        class Value {}
        let table = MTIWeakToStrongObjectsMapTable<Key, Value>()

        var key: Key? = Key()
        var value: Value? = Value()
        try table.setObject(value, forKey: #require(key))

        weak let weakValue = value
        value = nil

        #expect(weakValue != nil)

        #expect(try table.object(forKey: #require(key)) === weakValue)

        key = nil

        #expect(weakValue == nil)
    }

    @Test func directSIMDVectorSupport_float4() throws {
        var librarySource = Self.mtiShaderLibrarySource
        librarySource += """

        using namespace metalpetal;

        fragment float4 testRender(
                                VertexOut vertexIn [[stage_in]],
                                texture2d<float, access::sample> sourceTexture [[texture(0)]],
                                sampler sourceSampler [[sampler(0)]],
                                constant float4 &color [[buffer(0)]]
                                ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            return textureColor + color;
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: librarySource,
            compileOptions: nil
        )
        let renderKernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: .init(name: "testRender", libraryURL: libraryURL)
        )
        let image = MTIImage(
            color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = renderKernel.apply(
            to: [image],
            parameters: ["color": .simd(.float4(SIMD4<Float>(1, 0, 0, 0)))],
            outputDimensions: image.dimensions,
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func directSIMDVectorSupport_float3() throws {
        var librarySource = Self.mtiShaderLibrarySource
        librarySource += """

        using namespace metalpetal;

        fragment float4 testRender(
                                VertexOut vertexIn [[stage_in]],
                                texture2d<float, access::sample> sourceTexture [[texture(0)]],
                                sampler sourceSampler [[sampler(0)]],
                                constant float3 &color [[buffer(0)]]
                                ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            textureColor.rgb += color;
            return textureColor;
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: librarySource,
            compileOptions: nil
        )
        let renderKernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: .init(name: "testRender", libraryURL: libraryURL)
        )
        let image = MTIImage(
            color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = renderKernel.apply(
            to: [image],
            parameters: ["color": .simd(.float3(SIMD3<Float>(1, 0, 0)))],
            outputDimensions: image.dimensions,
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func directSIMDVectorSupport_float2x2() throws {
        var librarySource = Self.mtiShaderLibrarySource
        librarySource += """

        using namespace metalpetal;

        fragment float4 testRender(
                                VertexOut vertexIn [[stage_in]],
                                texture2d<float, access::sample> sourceTexture [[texture(0)]],
                                sampler sourceSampler [[sampler(0)]],
                                constant float2x2 &color [[buffer(0)]]
                                ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            return textureColor + float4(color[0][0],color[1][0],color[0][1],color[1][1]);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: librarySource,
            compileOptions: nil
        )
        let renderKernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: .init(name: "testRender", libraryURL: libraryURL)
        )
        let image = MTIImage(
            color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = renderKernel.apply(
            to: [image],
            parameters: ["color": .simd(.float2x2(float2x2(rows: [SIMD2<Float>(1, 0), SIMD2<Float>(1, 0)])))],
            outputDimensions: image.dimensions,
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
            #expect(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
        }
    }

    #if !os(tvOS)
    @Test func directSIMDVectorSupport_packedFloat3() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testCompute(
        texture2d<float, access::read> inTexture [[texture(0)]],
        texture2d<float, access::write> outTexture [[texture(1)]],
        constant packed_float3 &color [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
                return;
            }
            outTexture.write(inTexture.read(uint2(0,0)), gid);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: kernelSource,
            compileOptions: nil
        )
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
            name: "testCompute",
            libraryURL: libraryURL
        ))
        let context = try makeContext()
        context.lockForRendering()
        let state = try #require(context.kernelState(
            for: computeKernel,
            configuration: nil
        ) as? MTIComputePipeline)
        context.unlockForRendering()
        let commandEncoder = context.commandQueue.makeCommandBuffer()?.makeComputeCommandEncoder()
        defer {
            commandEncoder?.endEncoding()
        }
        do {
            try encodeKernelArguments(
                bindings: state.reflection.bindings,
                parameters: ["color": .simd(.float3(SIMD3<Float>(0, 0, 0)))],
                encoder: #require(commandEncoder)
            )
        } catch {
            let encoderError = try #require(error as? MTIError)
            #expect(encoderError == .parameterDataSizeMismatch)
        }
        try encodeKernelArguments(
            bindings: state.reflection.bindings,
            parameters: ["color": .simd(.packedFloat3(MTLPackedFloat3Make(0, 0, 0)))],
            encoder: #require(commandEncoder)
        )
    }
    #endif

    @Test func directSIMDVectorSupport_uchar4() throws {
        var librarySource = Self.mtiShaderLibrarySource
        librarySource += """

        using namespace metalpetal;

        fragment float4 testRender(
                                VertexOut vertexIn [[stage_in]],
                                texture2d<float, access::sample> sourceTexture [[texture(0)]],
                                sampler sourceSampler [[sampler(0)]],
                                constant uchar4 &color [[buffer(0)]]
                                ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            float r = color.r / 255.0;
            float g = color.g / 255.0;
            float b = color.b / 255.0;
            float a = color.a / 255.0;
            return textureColor + float4(r,g,b,a);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: librarySource,
            compileOptions: nil
        )
        let renderKernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: .init(name: "testRender", libraryURL: libraryURL)
        )
        let image = MTIImage(
            color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = renderKernel.apply(
            to: [image],
            parameters: ["color": .simd(.uchar4(SIMD4<UInt8>(128, 0, 0, 0)))],
            outputDimensions: image.dimensions,
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
            #expect(pixel.r == 128 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func directSIMDVectorSupport_typeMismatch() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testCompute(
        texture2d<float, access::read> inTexture [[texture(0)]],
        texture2d<float, access::write> outTexture [[texture(1)]],
        constant int4 &color [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
                return;
            }
            outTexture.write(inTexture.read(uint2(0,0)), gid);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: kernelSource,
            compileOptions: nil
        )
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
            name: "testCompute",
            libraryURL: libraryURL
        ))
        let context = try makeContext()
        context.lockForRendering()
        let state = try #require(context.kernelState(
            for: computeKernel,
            configuration: nil
        ) as? MTIComputePipeline)
        context.unlockForRendering()
        let commandEncoder = context.commandQueue.makeCommandBuffer()?.makeComputeCommandEncoder()
        defer {
            commandEncoder?.endEncoding()
        }
        do {
            try encodeKernelArguments(
                bindings: state.reflection.bindings,
                parameters: ["color": .simd(.float4(simd_make_float4(128, 0, 0, 0)))],
                encoder: #require(commandEncoder)
            )
        } catch {
            let encoderError = try #require(error as? MTIError)
            #expect(encoderError == .parameterDataTypeMismatch)
        }
    }

    @Test func directSIMDVectorSupport_int32_4() throws {
        var librarySource = Self.mtiShaderLibrarySource
        librarySource += """

        using namespace metalpetal;

        fragment float4 testRender(
                                VertexOut vertexIn [[stage_in]],
                                texture2d<float, access::sample> sourceTexture [[texture(0)]],
                                sampler sourceSampler [[sampler(0)]],
                                constant int4 &color [[buffer(0)]]
                                ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            float r = color.r / 255.0;
            float g = color.g / 255.0;
            float b = color.b / 255.0;
            float a = color.a / 255.0;
            return textureColor + float4(r,g,b,a);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: librarySource,
            compileOptions: nil
        )
        let renderKernel = MTIRenderPipelineKernel(
            vertexFunctionDescriptor: .passthroughVertex,
            fragmentFunctionDescriptor: .init(name: "testRender", libraryURL: libraryURL)
        )
        let image = MTIImage(
            color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1),
            sRGB: false,
            size: CGSize(width: 1, height: 1)
        )
        let outputImage = renderKernel.apply(
            to: [image],
            parameters: ["color": .simd(.int4(SIMD4<Int32>(128, 0, 0, 0)))],
            outputDimensions: image.dimensions,
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { pixel, _ in
            #expect(pixel.r == 128 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
        }
    }

    @Test func mTIVector() {
        let randomFloat = Float.random(in: 0 ... 1)
        #expect(MTIVector(value: SIMD2<Float>(repeating: randomFloat))
            .float2Value == SIMD2<Float>(repeating: randomFloat))
        #expect(MTIVector(value: SIMD3<Float>(repeating: randomFloat))
            .float3Value == SIMD3<Float>(repeating: randomFloat))
        #expect(MTIVector(value: SIMD4<Float>(repeating: randomFloat))
            .float4Value == SIMD4<Float>(repeating: randomFloat))

        let randomInt32 = Int32.random(in: Int32.min ... Int32.max)
        #expect(MTIVector(value: SIMD2<Int32>(repeating: randomInt32))
            .int2Value == SIMD2<Int32>(repeating: randomInt32))
        #expect(MTIVector(value: SIMD3<Int32>(repeating: randomInt32))
            .int3Value == SIMD3<Int32>(repeating: randomInt32))
        #expect(MTIVector(value: SIMD4<Int32>(repeating: randomInt32))
            .int4Value == SIMD4<Int32>(repeating: randomInt32))

        let randomInt16 = Int16.random(in: Int16.min ... Int16.max)
        #expect(MTIVector(value: SIMD2<Int16>(repeating: randomInt16))
            .short2Value == SIMD2<Int16>(repeating: randomInt16))
        #expect(MTIVector(value: SIMD3<Int16>(repeating: randomInt16))
            .short3Value == SIMD3<Int16>(repeating: randomInt16))
        #expect(MTIVector(value: SIMD4<Int16>(repeating: randomInt16))
            .short4Value == SIMD4<Int16>(repeating: randomInt16))

        let randomInt8 = Int8.random(in: Int8.min ... Int8.max)
        #expect(MTIVector(value: SIMD2<Int8>(repeating: randomInt8))
            .char2Value == SIMD2<Int8>(repeating: randomInt8))
        #expect(MTIVector(value: SIMD3<Int8>(repeating: randomInt8))
            .char3Value == SIMD3<Int8>(repeating: randomInt8))
        #expect(MTIVector(value: SIMD4<Int8>(repeating: randomInt8))
            .char4Value == SIMD4<Int8>(repeating: randomInt8))

        let randomUInt32 = UInt32.random(in: UInt32.min ... UInt32.max)
        #expect(MTIVector(value: SIMD2<UInt32>(repeating: randomUInt32))
            .uint2Value == SIMD2<UInt32>(repeating: randomUInt32))
        #expect(MTIVector(value: SIMD3<UInt32>(repeating: randomUInt32))
            .uint3Value == SIMD3<UInt32>(repeating: randomUInt32))
        #expect(MTIVector(value: SIMD4<UInt32>(repeating: randomUInt32))
            .uint4Value == SIMD4<UInt32>(repeating: randomUInt32))

        let randomUInt16 = UInt16.random(in: UInt16.min ... UInt16.max)
        #expect(MTIVector(value: SIMD2<UInt16>(repeating: randomUInt16))
            .ushort2Value == SIMD2<UInt16>(repeating: randomUInt16))
        #expect(MTIVector(value: SIMD3<UInt16>(repeating: randomUInt16))
            .ushort3Value == SIMD3<UInt16>(repeating: randomUInt16))
        #expect(MTIVector(value: SIMD4<UInt16>(repeating: randomUInt16))
            .ushort4Value == SIMD4<UInt16>(repeating: randomUInt16))

        let randomUInt8 = UInt8.random(in: UInt8.min ... UInt8.max)
        #expect(MTIVector(value: SIMD2<UInt8>(repeating: randomUInt8))
            .uchar2Value == SIMD2<UInt8>(repeating: randomUInt8))
        #expect(MTIVector(value: SIMD3<UInt8>(repeating: randomUInt8))
            .uchar3Value == SIMD3<UInt8>(repeating: randomUInt8))
        #expect(MTIVector(value: SIMD4<UInt8>(repeating: randomUInt8))
            .uchar4Value == SIMD4<UInt8>(repeating: randomUInt8))

        #expect(MTIVector(value: SIMD4<Float>(repeating: randomFloat)).float3Value == SIMD3<Float>(
            randomFloat,
            randomFloat,
            randomFloat
        ))
    }

    @Test func argumentsEncoding_basic() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testCompute(
            constant int &intValue [[buffer(0)]],
            constant uint &uintValue [[buffer(1)]],
            constant char &charValue [[buffer(2)]],
            constant uchar &ucharValue [[buffer(3)]],
            constant short &shortValue [[buffer(4)]],
            constant ushort &ushortValue [[buffer(5)]],
            constant float &floatValue [[buffer(6)]],
            constant half &halfValue [[buffer(7)]],
            constant bool &boolValue [[buffer(8)]],

            constant float2 &float2Value [[buffer(10)]],
            constant float4x4 &float4x4Value [[buffer(11)]],
            constant int2 &int2Value [[buffer(12)]],
            constant uchar2 &uchar2Value [[buffer(13)]]
        ) {}
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: kernelSource,
            compileOptions: nil
        )
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
            name: "testCompute",
            constantValues: nil,
            libraryURL: libraryURL
        ))
        let parameters: [String: MTIFunctionArgumentValue] = [
            "intValue": .int(-1),
            "uintValue": .uint(1),
            "charValue": .int(64),
            "ucharValue": .uint(128),
            "shortValue": .int(-1),
            "ushortValue": .uint(1),
            "floatValue": .float(1.0),
            "halfValue": .float(1.0),
            "boolValue": .bool(true),
            "float2Value": .simd(.float2(SIMD2<Float>(x: 1, y: 1))),
            "float4x4Value": .simd(.float4x4(simd_float4x4(1))),
            "int2Value": .simd(.int2(SIMD2<Int32>(x: 1, y: 1))),
            "uchar2Value": .simd(.uchar2(SIMD2<UInt8>(x: 1, y: 1))),
        ]
        let outputImage = computeKernel.apply(
            toInputImages: [],
            parameters: parameters,
            dispatchOptions: nil,
            outputTextureDimensions: MTITextureDimensions(width: 1, height: 1),
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        _ = try context.makeCGImage(from: outputImage)
    }

    @Test func argumentsEncoding_typeMismatch() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testCompute(
            constant int &intValue [[buffer(0)]]
        ) {}
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: kernelSource,
            compileOptions: nil
        )
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
            name: "testCompute",
            constantValues: nil,
            libraryURL: libraryURL
        ))
        let parameters: [String: MTIFunctionArgumentValue] = [
            "intValue": .simd(.float2(SIMD2<Float>(x: 0, y: 0))),
        ]
        let outputImage = computeKernel.apply(
            toInputImages: [],
            parameters: parameters,
            dispatchOptions: nil,
            outputTextureDimensions: MTITextureDimensions(width: 1, height: 1),
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        do {
            _ = try context.makeCGImage(from: outputImage)
            Issue.record()
        } catch {
            #expect((error as? MTIError) == .parameterDataTypeMismatch)
        }
    }

    @Test func argumentsEncoding_scalarTypeMismatch() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testCompute(
            constant float2 &float2Value [[buffer(0)]]
        ) {}
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(
            source: kernelSource,
            compileOptions: nil
        )
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(
            name: "testCompute",
            constantValues: nil,
            libraryURL: libraryURL
        ))
        let parameters: [String: MTIFunctionArgumentValue] = [
            "float2Value": .int(2),
        ]
        let outputImage = computeKernel.apply(
            toInputImages: [],
            parameters: parameters,
            dispatchOptions: nil,
            outputTextureDimensions: MTITextureDimensions(width: 1, height: 1),
            outputPixelFormat: .unspecified
        )
        let context = try makeContext()
        do {
            _ = try context.makeCGImage(from: outputImage)
            Issue.record()
        } catch let error as MTIError {
            #expect(error == .parameterDataTypeMismatch)
        }
    }

    @Test func geometryUtilities() {
        let aspectRatio = CGSize(width: 3, height: 4)
        let rect1 = CGRect(x: 100, y: 50, width: 300, height: 600)
        let rect2 = CGRect(x: 100, y: 50, width: 600, height: 300)
        let rect3 = CGRect(x: 100, y: 50, width: 300, height: 300)
        #expect(AVMakeRect(aspectRatio: aspectRatio, insideRect: rect1) == MTIMakeRect(
            aspectRatio: aspectRatio,
            insideRect: rect1
        ))
        #expect(AVMakeRect(aspectRatio: aspectRatio, insideRect: rect2) == MTIMakeRect(
            aspectRatio: aspectRatio,
            insideRect: rect2
        ))
        #expect(AVMakeRect(aspectRatio: aspectRatio, insideRect: rect3) == MTIMakeRect(
            aspectRatio: aspectRatio,
            insideRect: rect3
        ))
        #expect(MTIMakeRect(aspectRatio: aspectRatio, fillRect: rect1) == CGRect(
            x: 25,
            y: 50,
            width: 450,
            height: 600
        ))
        #expect(MTIMakeRect(aspectRatio: aspectRatio, fillRect: rect2) == CGRect(
            x: 100,
            y: -200,
            width: 600,
            height: 800
        ))
        #expect(MTIMakeRect(aspectRatio: aspectRatio, fillRect: rect3) == CGRect(
            x: 100,
            y: 0,
            width: 300,
            height: 400
        ))
    }
}
