// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLBlitCommandEncoderInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLCountersInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLFenceInternal.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/stubs.h>

@implementation MTLBlitCommandEncoderInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::BlitCommandEncoder> _encoder;
	std::shared_ptr<MTLIOSurfaceWriteSet> _iosurfaceWrites;
}

@synthesize device = _device;
@synthesize label = _label;

- (instancetype)initWithEncoder: (std::shared_ptr<Indium::BlitCommandEncoder>)encoder
                         device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_encoder = encoder;
		_device = [device retain];
	}
	return self;
}

- (void)setIOSurfaceWrites: (std::shared_ptr<MTLIOSurfaceWriteSet>)writes
{
	_iosurfaceWrites = writes;
}

- (void)noteWritten: (id<MTLTexture>)texture
{
	if (_iosurfaceWrites) {
		MTLIOSurfaceWriteSetNote(*_iosurfaceWrites, texture);
	}
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[super dealloc];
}

//
// overridden methods
//

- (void)sampleCountersInBuffer: (id<MTLCounterSampleBuffer>)sampleBuffer
                 atSampleIndex: (NSUInteger)sampleIndex
                   withBarrier: (BOOL)barrier
{
	_encoder->sampleCounters(MTLCounterSampleBufferGetIndium(sampleBuffer), sampleIndex, barrier);
}

- (void)endEncoding
{
	_encoder->endEncoding();
}

- (void)updateFence: (id<MTLFence>)fence
{
	_encoder->updateFence(MTLFenceGetIndium(fence));
}

- (void)waitForFence: (id<MTLFence>)fence
{
	_encoder->waitForFence(MTLFenceGetIndium(fence));
}

//
// methods
//

- (void)copyFromBuffer: (id<MTLBuffer>)sourceBuffer
          sourceOffset: (NSUInteger)sourceOffset
              toBuffer: (id<MTLBuffer>)destinationBuffer
     destinationOffset: (NSUInteger)destinationOffset
                 size: (NSUInteger)size
{
	_encoder->copy(MTLBufferGetIndium(sourceBuffer), sourceOffset,
	               MTLBufferGetIndium(destinationBuffer), destinationOffset, size);
}

- (void)copyFromBuffer: (id<MTLBuffer>)sourceBuffer
          sourceOffset: (NSUInteger)sourceOffset
     sourceBytesPerRow: (NSUInteger)sourceBytesPerRow
   sourceBytesPerImage: (NSUInteger)sourceBytesPerImage
           sourceSize: (MTLSize)sourceSize
             toTexture: (id<MTLTexture>)destinationTexture
    destinationSlice: (NSUInteger)destinationSlice
  destinationLevel: (NSUInteger)destinationLevel
 destinationOrigin: (MTLOrigin)destinationOrigin
{
	[self copyFromBuffer: sourceBuffer
	          sourceOffset: sourceOffset
	     sourceBytesPerRow: sourceBytesPerRow
	   sourceBytesPerImage: sourceBytesPerImage
	           sourceSize: sourceSize
	             toTexture: destinationTexture
	    destinationSlice: destinationSlice
	  destinationLevel: destinationLevel
	 destinationOrigin: destinationOrigin
	               options: MTLBlitOptionNone];
}

- (void)copyFromBuffer: (id<MTLBuffer>)sourceBuffer
          sourceOffset: (NSUInteger)sourceOffset
     sourceBytesPerRow: (NSUInteger)sourceBytesPerRow
   sourceBytesPerImage: (NSUInteger)sourceBytesPerImage
           sourceSize: (MTLSize)sourceSize
             toTexture: (id<MTLTexture>)destinationTexture
    destinationSlice: (NSUInteger)destinationSlice
  destinationLevel: (NSUInteger)destinationLevel
 destinationOrigin: (MTLOrigin)destinationOrigin
               options: (MTLBlitOption)options
{
	[self noteWritten: destinationTexture];
	_encoder->copy(MTLBufferGetIndium(sourceBuffer), sourceOffset,
	               sourceBytesPerRow, sourceBytesPerImage, MTLSizeToIndium(sourceSize),
	               MTLTextureGetIndium(destinationTexture), destinationSlice,
	               destinationLevel, MTLOriginToIndium(destinationOrigin),
	               static_cast<Indium::BlitOption>(options));
}

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
             sourceSlice: (NSUInteger)sourceSlice
             sourceLevel: (NSUInteger)sourceLevel
            sourceOrigin: (MTLOrigin)sourceOrigin
              sourceSize: (MTLSize)sourceSize
                toBuffer: (id<MTLBuffer>)destinationBuffer
       destinationOffset: (NSUInteger)destinationOffset
  destinationBytesPerRow: (NSUInteger)destinationBytesPerRow
destinationBytesPerImage: (NSUInteger)destinationBytesPerImage
{
	[self copyFromTexture: sourceTexture
	           sourceSlice: sourceSlice
	           sourceLevel: sourceLevel
	          sourceOrigin: sourceOrigin
	            sourceSize: sourceSize
	        sourceOptions: MTLBlitOptionNone
	              toBuffer: destinationBuffer
	     destinationOffset: destinationOffset
	    destinationBytesPerRow: destinationBytesPerRow
	destinationBytesPerImage: destinationBytesPerImage
	                 options: MTLBlitOptionNone];
}

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
             sourceSlice: (NSUInteger)sourceSlice
             sourceLevel: (NSUInteger)sourceLevel
            sourceOrigin: (MTLOrigin)sourceOrigin
              sourceSize: (MTLSize)sourceSize
          sourceOptions: (MTLBlitOption)sourceOptions
                toBuffer: (id<MTLBuffer>)destinationBuffer
       destinationOffset: (NSUInteger)destinationOffset
  destinationBytesPerRow: (NSUInteger)destinationBytesPerRow
destinationBytesPerImage: (NSUInteger)destinationBytesPerImage
               options: (MTLBlitOption)options
{
	// indium takes a single option set for the whole copy, and it has no way to
	// express the source-side options, so those are dropped here.
	_encoder->copy(MTLTextureGetIndium(sourceTexture), sourceSlice, sourceLevel,
	               MTLOriginToIndium(sourceOrigin), MTLSizeToIndium(sourceSize),
	               MTLBufferGetIndium(destinationBuffer), destinationOffset,
	               destinationBytesPerRow, destinationBytesPerImage,
	               static_cast<Indium::BlitOption>(options));
}

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
             sourceSlice: (NSUInteger)sourceSlice
             sourceLevel: (NSUInteger)sourceLevel
            sourceOrigin: (MTLOrigin)sourceOrigin
              sourceSize: (MTLSize)sourceSize
               toTexture: (id<MTLTexture>)destinationTexture
      destinationSlice: (NSUInteger)destinationSlice
    destinationLevel: (NSUInteger)destinationLevel
   destinationOrigin: (MTLOrigin)destinationOrigin
{
	// An empty initial layer has no texels to copy; do not dereference its
	// not-yet-created source texture or encode a zero-extent Vulkan copy.
	if (sourceSize.width == 0 || sourceSize.height == 0 || sourceSize.depth == 0)
		return;
	[self noteWritten: destinationTexture];
	_encoder->copy(MTLTextureGetIndium(sourceTexture), sourceSlice, sourceLevel,
	               MTLOriginToIndium(sourceOrigin), MTLSizeToIndium(sourceSize),
	               MTLTextureGetIndium(destinationTexture), destinationSlice,
	               destinationLevel, MTLOriginToIndium(destinationOrigin));
}

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
              toTexture: (id<MTLTexture>)destinationTexture
{
	[self noteWritten: destinationTexture];
	_encoder->copy(MTLTextureGetIndium(sourceTexture),
	               MTLTextureGetIndium(destinationTexture));
}

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
             sourceSlice: (NSUInteger)sourceSlice
             sourceLevel: (NSUInteger)sourceLevel
               toTexture: (id<MTLTexture>)destinationTexture
      destinationSlice: (NSUInteger)destinationSlice
    destinationLevel: (NSUInteger)destinationLevel
            sliceCount: (NSUInteger)sliceCount
            levelCount: (NSUInteger)levelCount
{
	[self noteWritten: destinationTexture];
	_encoder->copy(MTLTextureGetIndium(sourceTexture), sourceSlice, sourceLevel,
	               MTLTextureGetIndium(destinationTexture), destinationSlice,
	               destinationLevel, sliceCount, levelCount);
}

- (void)fillBuffer: (id<MTLBuffer>)buffer
              range: (NSRange)range
             value: (uint8_t)value
{
	_encoder->fillBuffer(MTLBufferGetIndium(buffer), NSRangeToIndium(range), value);
}

- (void)generateMipmapsForTexture: (id<MTLTexture>)texture
{
	[self noteWritten: texture];
	_encoder->generateMipmapsForTexture(MTLTextureGetIndium(texture));
}

- (void)synchronizeResource: (id<MTLResource>)resource
{
	if ([resource conformsToProtocol: @protocol(MTLBuffer)]) {
		_encoder->synchronize(MTLBufferGetIndium((id<MTLBuffer>)resource));
	} else if ([resource conformsToProtocol: @protocol(MTLTexture)]) {
		_encoder->synchronize(MTLTextureGetIndium((id<MTLTexture>)resource));
	}
}

// Indium synchronizes a texture whole, which covers the one image asked for.
- (void)synchronizeTexture: (id<MTLTexture>)texture
                     slice: (NSUInteger)slice
                     level: (NSUInteger)level
{
	_encoder->synchronize(MTLTextureGetIndium(texture));
}

#else

@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
