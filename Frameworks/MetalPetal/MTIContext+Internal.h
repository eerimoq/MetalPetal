//
//  MTIContext+Internal.h
//  MetalPetal
//
//  Created by Yu Ao on 07/01/2018.
//

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#if __has_include(<MetalPetal/MetalPetal.h>)
#import <MetalPetal/MTIContext.h>
#else
#import "MTIContext.h"
#endif

@class MTIImage;
@protocol MTIKernelConfiguration, MTIKernel, MTIImagePromise;

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_subclassing_restricted))
@interface MTIImagePromiseRenderTarget : NSObject

@property (nonatomic,strong,readonly,nullable) id<MTLTexture> texture;

- (BOOL)retainTexture;

- (void)releaseTexture;

@end

typedef NSString * MTIContextPromiseAssociatedValueTableName NS_EXTENSIBLE_STRING_ENUM;
typedef NSString * MTIContextImageAssociatedValueTableName NS_EXTENSIBLE_STRING_ENUM;

@class MTIFunctionDescriptor, MTISamplerDescriptor, MTIRenderPipeline, MTIComputePipeline, MTITextureDescriptor;

@interface MTIContext (Internal)

#pragma mark - Render Target

- (nullable MTIImagePromiseRenderTarget *)newRenderTargetWithReusableTextureDescriptor:(MTITextureDescriptor *)textureDescriptor error:(NSError **)error NS_SWIFT_NAME(makeRenderTarget(reusableTextureDescriptor:));

- (MTIImagePromiseRenderTarget *)newRenderTargetWithTexture:(id<MTLTexture>)texture NS_SWIFT_NAME(makeRenderTarget(texture:));

#pragma mark - Lock

- (void)lockForRendering;

- (void)unlockForRendering;

#pragma mark - Cache

- (nullable id<MTLFunction>)functionWithDescriptor:(MTIFunctionDescriptor *)descriptor error:(NSError **)error;

- (nullable id<MTLSamplerState>)samplerStateWithDescriptor:(MTISamplerDescriptor *)descriptor error:(NSError **)error;

- (nullable MTIRenderPipeline *)renderPipelineWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor error:(NSError **)error;

- (nullable MTIComputePipeline *)computePipelineWithDescriptor:(MTLComputePipelineDescriptor *)descriptor error:(NSError **)error;

- (nullable id)kernelStateForKernel:(id<MTIKernel>)kernel configuration:(nullable id<MTIKernelConfiguration>)configuration error:(NSError **)error;

#pragma mark - Privately Used Caches

/* Weak to strong tables */

- (nullable id)valueForPromise:(id)promise inTable:(MTIContextPromiseAssociatedValueTableName)tableName NS_SWIFT_NAME(value(forPromise:in:));

- (void)setValue:(nullable id)value forPromise:(id)promise inTable:(MTIContextPromiseAssociatedValueTableName)tableName NS_SWIFT_NAME(setValue(_:forPromise:in:));

- (nullable id)valueForImage:(id)image inTable:(MTIContextImageAssociatedValueTableName)tableName NS_SWIFT_NAME(value(forImage:in:));

- (void)setValue:(nullable id)value forImage:(id)image inTable:(MTIContextImageAssociatedValueTableName)tableName NS_SWIFT_NAME(setValue(_:forImage:in:));

/* MTIImagePromise (weak) to MTIImagePromiseRenderTarget (weak) table. */

- (void)setRenderTarget:(MTIImagePromiseRenderTarget *)renderTarget forPromise:(id)promise NS_SWIFT_NAME(setRenderTarget(_:for:));

- (nullable MTIImagePromiseRenderTarget *)renderTargetForPromise:(id)promise NS_SWIFT_NAME(renderTarget(for:));

@end

NS_ASSUME_NONNULL_END
