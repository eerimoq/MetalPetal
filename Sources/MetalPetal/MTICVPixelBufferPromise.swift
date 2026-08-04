//
//  MTICVPixelBufferPromise.swift
//  Pods
//
//  Created by YuAo on 21/07/2017.
//

import CoreImage
import CoreVideo
import Foundation
import Metal
import simd

private let MTIColorConversionVertexFunctionName = "colorConversionVertex"
private let MTIColorConversionFragmentFunctionName = "colorConversionFragment"

private let MTIYUVColorConversionVertexData: [Float] = [
    -1.0, -1.0, 0.0, 1.0,
    1.0, -1.0, 1.0, 1.0,
    -1.0, 1.0, 0.0, 0.0,
    1.0, 1.0, 1.0, 0.0,
]

// Matches the Metal shader struct. Keep the layout (matrix_float3x3 + vector_float3).
private struct MTIYUVColorConversion {
    var matrix: matrix_float3x3
    var offset: vector_float3
}

// BT.601
private let MTIYUVColorConversion601 = MTIYUVColorConversion(
    matrix: matrix_float3x3(columns: (
        simd_float3(1.164, 1.164, 1.164),
        simd_float3(0.000, -0.392, 2.017),
        simd_float3(1.596, -0.813, 0.000)
    )),
    offset: simd_float3(-(16.0 / 255.0), -0.5, -0.5)
)

// BT.601 Full Range
private let MTIYUVColorConversion601FullRange = MTIYUVColorConversion(
    matrix: matrix_float3x3(columns: (
        simd_float3(1.000, 1.000, 1.000),
        simd_float3(0.000, -0.343, 1.765),
        simd_float3(1.400, -0.711, 0.000)
    )),
    offset: simd_float3(0.0, -0.5, -0.5)
)

// BT.709
private let MTIYUVColorConversion709 = MTIYUVColorConversion(
    matrix: matrix_float3x3(columns: (
        simd_float3(1.164, 1.164, 1.164),
        simd_float3(0.000, -0.213, 2.112),
        simd_float3(1.793, -0.533, 0.000)
    )),
    offset: simd_float3(-(16.0 / 255.0), -0.5, -0.5)
)

let cvMetalTextureHolderTable =
    MTIContextPromiseAssociatedValueTableName(
        rawValue: "MTIContextCVPixelBufferPromiseCVMetalTextureHolderTable"
    )

// for internal use only
private func MTIMTLPixelFormat(forCVPixelFormatType type: OSType, sRGB: Bool) -> MTLPixelFormat {
    switch type {
    case kCVPixelFormatType_32BGRA:
        return sRGB ? .bgra8Unorm_srgb : .bgra8Unorm
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
        return sRGB ? .bgra8Unorm_srgb : .bgra8Unorm
    case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
        return sRGB ? .bgra8Unorm_srgb : .bgra8Unorm
    case kCVPixelFormatType_32RGBA:
        return sRGB ? .rgba8Unorm_srgb : .rgba8Unorm
    case kCVPixelFormatType_DisparityFloat16, kCVPixelFormatType_DepthFloat16,
         kCVPixelFormatType_OneComponent16Half:
        return .r16Float
    case kCVPixelFormatType_DisparityFloat32, kCVPixelFormatType_DepthFloat32,
         kCVPixelFormatType_OneComponent32Float:
        return .r32Float
    case kCVPixelFormatType_OneComponent8:
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return sRGB ? .r8Unorm_srgb : .r8Unorm
        #else
        // R8Unorm_sRGB texture is not available on macOS.
        return sRGB ? .invalid : .r8Unorm
        #endif
    default:
        return .invalid
    }
}

public final class MTICVPixelBufferPromise: MTIImagePromise {
    public let pixelBuffer: CVPixelBuffer
    public let renderingAPI: MTICVPixelBufferRenderingAPI
    private let sRGB: Bool
    private let coreImageRendererDefaultTextureDescriptor: MTITextureDescriptor

    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init(
        cvPixelBuffer pixelBuffer: CVPixelBuffer,
        options: MTICVPixelBufferRenderingOptions,
        alphaType: MTIAlphaType
    ) {
        self.alphaType = alphaType
        renderingAPI = options.renderingAPI
        self.pixelBuffer = pixelBuffer
        dimensions = MTITextureDimensions(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            depth: 1
        )
        sRGB = options.sRGB
        coreImageRendererDefaultTextureDescriptor = MTITextureDescriptor(
            pixelFormat: MTIMTLPixelFormat(
                forCVPixelFormatType: CVPixelBufferGetPixelFormatType(pixelBuffer),
                sRGB: options.sRGB
            ),
            width: Int(CVPixelBufferGetWidth(pixelBuffer)),
            height: Int(CVPixelBufferGetHeight(pixelBuffer)),
            mipmapped: false,
            usage: [.shaderRead, .shaderWrite],
            resourceOptions: .storageModePrivate
        )
    }

    public var dependencies: [MTIImage] {
        []
    }

    private func colorConversionRenderPipeline(
        colorAttachmentPixelFormat pixelFormat: MTLPixelFormat,
        context: MTIContext
    ) throws -> MTIRenderPipeline {
        let vertexFunction = try context.function(with: .init(name: MTIColorConversionVertexFunctionName))
        let fragmentFunction = try context.function(with: .init(name: MTIColorConversionFragmentFunctionName))
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .invalid
        return try context.renderPipeline(with: renderPipelineDescriptor)
    }

    private func resolveCI(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        if coreImageRendererDefaultTextureDescriptor.pixelFormat == .invalid {
            throw MTIError.unsupportedCVPixelBufferFormat
        }
        let renderTarget = try renderingContext.context
            .makeRenderTarget(reusableTextureDescriptor: coreImageRendererDefaultTextureDescriptor)
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace: CGColorSpace? = sRGB ? nil : CGColorSpaceCreateDeviceRGB()
        let destination = CIRenderDestination(
            mtlTexture: renderTarget.texture!,
            commandBuffer: renderingContext.commandBuffer
        )
        destination.colorSpace = colorSpace
        destination.isFlipped = true
        try renderingContext.context.coreImageContext.startTask(toRender: image, to: destination)
        return renderTarget
    }

    private func resolveMTI(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        switch pixelFormatType {
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
             kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
            guard renderingContext.context.isYCbCrPixelFormatSupported else {
                throw MTIError.unsupportedCVPixelBufferFormat
            }
            let pixelFormat: MTLPixelFormat = sRGB ? .yCbCr10_420_2p_srgb : .yCbCr10_420_2p
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixelFormat,
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer),
                mipmapped: false
            )
            textureDescriptor.usage = .shaderRead
            let cvMetalTexture = try renderingContext.context.coreVideoTextureBridge.makeTexture(
                with: pixelBuffer,
                textureDescriptor: textureDescriptor,
                planeIndex: 0
            )
            renderingContext.context.setValue(
                cvMetalTexture,
                forPromise: self,
                in: cvMetalTextureHolderTable
            )
            return renderingContext.context.makeRenderTarget(texture: cvMetalTexture.texture)

        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            if renderingContext.context.isYCbCrPixelFormatSupported {
                let pixelFormat: MTLPixelFormat = sRGB ? .yCbCr8_420_2p_srgb : .yCbCr8_420_2p
                let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: pixelFormat,
                    width: CVPixelBufferGetWidth(pixelBuffer),
                    height: CVPixelBufferGetHeight(pixelBuffer),
                    mipmapped: false
                )
                textureDescriptor.usage = .shaderRead
                let cvMetalTexture = try renderingContext.context.coreVideoTextureBridge.makeTexture(
                    with: pixelBuffer,
                    textureDescriptor: textureDescriptor,
                    planeIndex: 0
                )
                renderingContext.context.setValue(
                    cvMetalTexture,
                    forPromise: self,
                    in: cvMetalTextureHolderTable
                )
                return renderingContext.context.makeRenderTarget(texture: cvMetalTexture.texture)
            } else {
                let isFullYUVRange = pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange

                var preferredConversion = if let colorAttachments =
                    CVBufferCopyAttachment(
                        pixelBuffer,
                        kCVImageBufferYCbCrMatrixKey,
                        nil
                    )
                {
                    if CFStringCompare(
                        (colorAttachments as! CFString),
                        kCVImageBufferYCbCrMatrix_ITU_R_601_4,
                        .compareCaseInsensitive
                    ) == .compareEqualTo {
                        isFullYUVRange ? MTIYUVColorConversion601FullRange : MTIYUVColorConversion601
                    } else {
                        MTIYUVColorConversion709
                    }
                } else {
                    isFullYUVRange ? MTIYUVColorConversion601FullRange : MTIYUVColorConversion601
                }
                let plane0Width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
                let plane0Height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
                let yTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .r8Unorm,
                    width: plane0Width,
                    height: plane0Height,
                    mipmapped: false
                )
                yTextureDescriptor.usage = .shaderRead
                let cvMetalTextureY = try renderingContext.context.coreVideoTextureBridge.makeTexture(
                    with: pixelBuffer,
                    textureDescriptor: yTextureDescriptor,
                    planeIndex: 0
                )
                let plane1Width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
                let plane1Height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
                let uvTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .rg8Unorm,
                    width: plane1Width,
                    height: plane1Height,
                    mipmapped: false
                )
                uvTextureDescriptor.usage = .shaderRead
                let cvMetalTextureCbCr = try renderingContext.context.coreVideoTextureBridge.makeTexture(
                    with: pixelBuffer,
                    textureDescriptor: uvTextureDescriptor,
                    planeIndex: 1
                )
                // Render Pipeline
                let pixelFormat: MTLPixelFormat = .bgra8Unorm
                let textureDescriptor = MTITextureDescriptor(
                    pixelFormat: pixelFormat,
                    width: Int(CVPixelBufferGetWidth(pixelBuffer)),
                    height: Int(CVPixelBufferGetHeight(pixelBuffer)),
                    mipmapped: false,
                    usage: [.shaderRead, .renderTarget],
                    resourceOptions: .storageModePrivate
                )
                let renderTarget = try renderingContext.context
                    .makeRenderTarget(reusableTextureDescriptor: textureDescriptor)

                let renderPassDescriptor = MTLRenderPassDescriptor()
                renderPassDescriptor.colorAttachments[0].texture = renderTarget.texture
                renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
                renderPassDescriptor.colorAttachments[0].storeAction = .store
                let renderPipeline = try colorConversionRenderPipeline(
                    colorAttachmentPixelFormat: renderPassDescriptor.colorAttachments[0].texture!.pixelFormat,
                    context: renderingContext.context
                )
                let renderCommandEncoder = renderingContext.commandBuffer
                    .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
                renderCommandEncoder.setRenderPipelineState(renderPipeline.state)
                renderCommandEncoder.setVertexBytes(
                    MTIYUVColorConversionVertexData,
                    length: 16 * MemoryLayout<Float>.size,
                    index: 0
                )
                renderCommandEncoder.setFragmentTexture(cvMetalTextureY.texture, index: 0)
                renderCommandEncoder.setFragmentTexture(cvMetalTextureCbCr.texture, index: 1)
                withUnsafeBytes(of: &preferredConversion) { buffer in
                    renderCommandEncoder.setFragmentBytes(
                        buffer.baseAddress!,
                        length: MemoryLayout<MTIYUVColorConversion>.size,
                        index: 0
                    )
                }
                var convertToLinearRGB = sRGB
                renderCommandEncoder.setFragmentBytes(
                    &convertToLinearRGB,
                    length: MemoryLayout<Bool>.size,
                    index: 1
                )
                renderCommandEncoder.drawPrimitives(
                    type: .triangleStrip,
                    vertexStart: 0,
                    vertexCount: 4,
                    instanceCount: 1
                )
                renderCommandEncoder.endEncoding()
                return renderTarget
            }

        default:
            let pixelFormat = MTIMTLPixelFormat(
                forCVPixelFormatType: CVPixelBufferGetPixelFormatType(pixelBuffer),
                sRGB: sRGB
            )
            if pixelFormat == .invalid {
                throw MTIError.unsupportedCVPixelBufferFormat
            }
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixelFormat,
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer),
                mipmapped: false
            )
            textureDescriptor.usage = .shaderRead
            let cvMetalTexture = try renderingContext.context.coreVideoTextureBridge.makeTexture(
                with: pixelBuffer,
                textureDescriptor: textureDescriptor,
                planeIndex: 0
            )
            renderingContext.context.setValue(
                cvMetalTexture,
                forPromise: self,
                in: cvMetalTextureHolderTable
            )
            #if os(iOS) && !targetEnvironment(macCatalyst)
            // Workaround for #64. See https://github.com/MetalPetal/MetalPetal/issues/64
            if !renderingContext.context.device.supportsFamily(.apple2) {
                let renderTarget = try renderingContext.context
                    .makeRenderTarget(reusableTextureDescriptor: textureDescriptor.makeMTITextureDescriptor())
                guard let commandEncoder = renderingContext.commandBuffer.makeBlitCommandEncoder() else {
                    throw MTIError.failedToCreateCommandEncoder
                }
                commandEncoder.copy(
                    from: cvMetalTexture.texture,
                    sourceSlice: 0,
                    sourceLevel: 0,
                    sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                    sourceSize: MTLSize(
                        width: cvMetalTexture.texture.width,
                        height: cvMetalTexture.texture.height,
                        depth: cvMetalTexture.texture.depth
                    ),
                    to: renderTarget.texture!,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
                )
                commandEncoder.endEncoding()
                return renderTarget
            }
            #endif
            return renderingContext.context.makeRenderTarget(texture: cvMetalTexture.texture)
        }
    }

    private static var didWarnAboutNonIOSurfaceFallback = false

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        if renderingAPI == .metalPetal, CVPixelBufferGetIOSurface(pixelBuffer) == nil {
            if !MTICVPixelBufferPromise.didWarnAboutNonIOSurfaceFallback {
                MTICVPixelBufferPromise.didWarnAboutNonIOSurfaceFallback = true
                NSLog("""
                [MTICVPixelBufferPromise] Warning once only: CVPixelBuffer is not \
                backed by IOSurface, fallback to use MTICVPixelBufferRenderingAPICoreImage.
                """)
            }
            return try resolveCI(with: renderingContext)
        }
        switch renderingAPI {
        case .metalPetal:
            return try resolveMTI(with: renderingContext)
        case .coreImage:
            return try resolveCI(with: renderingContext)
        }
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: CIImage(cvPixelBuffer: pixelBuffer))
    }
}

public final class MTICVPixelBufferDirectBridgePromise: MTIImagePromise {
    private let pixelBuffer: CVPixelBuffer
    private let textureDescriptor: MTLTextureDescriptor
    private let planeIndex: Int
    public let dimensions: MTITextureDimensions
    public let alphaType: MTIAlphaType

    public init(
        cvPixelBuffer pixelBuffer: CVPixelBuffer,
        planeIndex: Int,
        textureDescriptor: MTLTextureDescriptor,
        alphaType: MTIAlphaType
    ) {
        dimensions = MTITextureDimensions(
            width: textureDescriptor.width,
            height: textureDescriptor.height,
            depth: textureDescriptor.depth
        )
        self.alphaType = alphaType
        self.textureDescriptor = textureDescriptor.copy() as! MTLTextureDescriptor
        self.planeIndex = planeIndex
        self.pixelBuffer = pixelBuffer
    }

    public func resolve(with renderingContext: MTIImageRenderingContext) throws
        -> MTIImagePromiseRenderTarget
    {
        let cvMetalTexture = try renderingContext.context.coreVideoTextureBridge.makeTexture(
            with: pixelBuffer,
            textureDescriptor: textureDescriptor,
            planeIndex: Int(planeIndex)
        )
        renderingContext.context.setValue(
            cvMetalTexture,
            forPromise: self,
            in: cvMetalTextureHolderTable
        )
        return renderingContext.context.makeRenderTarget(texture: cvMetalTexture.texture)
    }

    public func updatingDependencies(_: [MTIImage]) -> Self {
        self
    }

    public var dependencies: [MTIImage] {
        []
    }

    public var debugInfo: MTIImagePromiseDebugInfo {
        MTIImagePromiseDebugInfo(promise: self, type: .source, content: CIImage(cvPixelBuffer: pixelBuffer))
    }
}
