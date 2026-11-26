// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLARGUMENTENCODER_H_
#define _METAL_MTLARGUMENTENCODER_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLBuffer;
@protocol MTLTexture;
@protocol MTLSamplerState;
@protocol MTLRenderPipelineState;
@protocol MTLComputePipelineState;

/**
 * Writes resources into an argument buffer at the layout a function's argument buffer has.
 *
 * Only the protocol is declared: -[MTLFunction newArgumentEncoderWithBufferIndex:] returns nil (see MTLLibrary.mm),
 * as indium does not give the argument buffer layout an encoder needs.
 */
@protocol MTLArgumentEncoder <NSObject>

@property(readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;
@property(readonly) NSUInteger encodedLength;
@property(readonly) NSUInteger alignment;

- (void)setArgumentBuffer: (nullable id<MTLBuffer>)argumentBuffer offset: (NSUInteger)offset;
- (void)setArgumentBuffer: (nullable id<MTLBuffer>)argumentBuffer startOffset: (NSUInteger)startOffset arrayElement: (NSUInteger)arrayElement;
- (void)setBuffer: (nullable id<MTLBuffer>)buffer offset: (NSUInteger)offset atIndex: (NSUInteger)index;
- (void)setBuffers: (const id<MTLBuffer> _Nullable[_Nonnull])buffers offsets: (const NSUInteger[_Nonnull])offsets withRange: (NSRange)range;
- (void)setTexture: (nullable id<MTLTexture>)texture atIndex: (NSUInteger)index;
- (void)setTextures: (const id<MTLTexture> _Nullable[_Nonnull])textures withRange: (NSRange)range;
- (void)setSamplerState: (nullable id<MTLSamplerState>)sampler atIndex: (NSUInteger)index;
- (void)setSamplerStates: (const id<MTLSamplerState> _Nullable[_Nonnull])samplers withRange: (NSRange)range;
- (void*)constantDataAtIndex: (NSUInteger)index;
- (void)setRenderPipelineState: (nullable id<MTLRenderPipelineState>)pipeline atIndex: (NSUInteger)index;
- (void)setComputePipelineState: (nullable id<MTLComputePipelineState>)pipeline atIndex: (NSUInteger)index;
- (nullable id<MTLArgumentEncoder>)newArgumentEncoderForBufferAtIndex: (NSUInteger)index;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLARGUMENTENCODER_H_
