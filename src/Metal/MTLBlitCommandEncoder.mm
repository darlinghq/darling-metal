// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLBlitCommandEncoderInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/stubs.h>

@implementation MTLBlitCommandEncoderInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::BlitCommandEncoder> _encoder;
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

- (void)dealloc
{
	[_device release];
	[_label release];
	[super dealloc];
}

//
// overridden methods
//

- (void)endEncoding
{
	_encoder->endEncoding();
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
	_encoder->copy(((MTLBufferInternal*)sourceBuffer).buffer, sourceOffset,
	               ((MTLBufferInternal*)destinationBuffer).buffer, destinationOffset, size);
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
	_encoder->copy(((MTLBufferInternal*)sourceBuffer).buffer, sourceOffset,
	               sourceBytesPerRow, sourceBytesPerImage, MTLSizeToIndium(sourceSize),
	               ((MTLTextureInternal*)destinationTexture).texture, destinationSlice,
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
	_encoder->copy(((MTLTextureInternal*)sourceTexture).texture, sourceSlice, sourceLevel,
	               MTLOriginToIndium(sourceOrigin), MTLSizeToIndium(sourceSize),
	               ((MTLBufferInternal*)destinationBuffer).buffer, destinationOffset,
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
	_encoder->copy(((MTLTextureInternal*)sourceTexture).texture, sourceSlice, sourceLevel,
	               MTLOriginToIndium(sourceOrigin), MTLSizeToIndium(sourceSize),
	               ((MTLTextureInternal*)destinationTexture).texture, destinationSlice,
	               destinationLevel, MTLOriginToIndium(destinationOrigin));
}

- (void)copyFromTexture: (id<MTLTexture>)sourceTexture
              toTexture: (id<MTLTexture>)destinationTexture
{
	_encoder->copy(((MTLTextureInternal*)sourceTexture).texture,
	               ((MTLTextureInternal*)destinationTexture).texture);
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
	_encoder->copy(((MTLTextureInternal*)sourceTexture).texture, sourceSlice, sourceLevel,
	               ((MTLTextureInternal*)destinationTexture).texture, destinationSlice,
	               destinationLevel, sliceCount, levelCount);
}

- (void)fillBuffer: (id<MTLBuffer>)buffer
              range: (NSRange)range
             value: (uint8_t)value
{
	_encoder->fillBuffer(((MTLBufferInternal*)buffer).buffer, NSRangeToIndium(range), value);
}

- (void)generateMipmapsForTexture: (id<MTLTexture>)texture
{
	_encoder->generateMipmapsForTexture(((MTLTextureInternal*)texture).texture);
}

#else

@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
