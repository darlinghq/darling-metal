// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLBlitPassInternal.h>
#import <Metal/MTLCountersInternal.h>
#import <Metal/stubs.h>

@implementation MTLBlitPassSampleBufferAttachmentDescriptor

#if DARLING_METAL_ENABLED

@synthesize sampleBuffer = _sampleBuffer;
@synthesize startOfEncoderSampleIndex = _startOfEncoderSampleIndex;
@synthesize endOfEncoderSampleIndex = _endOfEncoderSampleIndex;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_startOfEncoderSampleIndex = MTLCounterDontSample;
		_endOfEncoderSampleIndex = MTLCounterDontSample;
	}
	return self;
}

- (void)dealloc
{
	[(id)_sampleBuffer release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLBlitPassSampleBufferAttachmentDescriptor* copy = [[MTLBlitPassSampleBufferAttachmentDescriptor allocWithZone: zone] init];
	copy.sampleBuffer = _sampleBuffer;
	copy.startOfEncoderSampleIndex = _startOfEncoderSampleIndex;
	copy.endOfEncoderSampleIndex = _endOfEncoderSampleIndex;
	return copy;
}

#else

@dynamic sampleBuffer;
@dynamic startOfEncoderSampleIndex;
@dynamic endOfEncoderSampleIndex;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLBlitPassSampleBufferAttachmentDescriptorArray

#if DARLING_METAL_ENABLED

{
	NSMutableDictionary<NSNumber*, MTLBlitPassSampleBufferAttachmentDescriptor*>* _dict;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_dict = [NSMutableDictionary new];
	}
	return self;
}

- (void)dealloc
{
	[_dict release];
	[super dealloc];
}

- (MTLBlitPassSampleBufferAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)index
{
	if (!_dict[@(index)]) {
		_dict[@(index)] = [[MTLBlitPassSampleBufferAttachmentDescriptor new] autorelease];
	}
	return [[_dict[@(index)] retain] autorelease];
}

-    (void)setObject: (MTLBlitPassSampleBufferAttachmentDescriptor*)desc
  atIndexedSubscript: (NSUInteger)index
{
	if (desc == nil) {
		[_dict removeObjectForKey: @(index)];
	} else {
		_dict[@(index)] = desc;
	}
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLBlitPassSampleBufferAttachmentDescriptorArray* copy = [[MTLBlitPassSampleBufferAttachmentDescriptorArray allocWithZone: zone] init];
	[_dict enumerateKeysAndObjectsUsingBlock: ^(NSNumber* key, MTLBlitPassSampleBufferAttachmentDescriptor* value, BOOL* stop) {
		copy->_dict[key] = [[value copy] autorelease];
	}];
	return copy;
}

- (std::unordered_map<size_t, Indium::BlitPassSampleBufferAttachmentDescriptor>)asIndiumAttachments
{
	__block std::unordered_map<size_t, Indium::BlitPassSampleBufferAttachmentDescriptor> result;
	[_dict enumerateKeysAndObjectsUsingBlock: ^(NSNumber* key, MTLBlitPassSampleBufferAttachmentDescriptor* value, BOOL* stop) {
		if (value.sampleBuffer != nil) {
			result[key.unsignedIntegerValue] = Indium::BlitPassSampleBufferAttachmentDescriptor {
				MTLCounterSampleBufferGetIndium(value.sampleBuffer),
				value.startOfEncoderSampleIndex,
				value.endOfEncoderSampleIndex,
			};
		}
	}];
	return result;
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLBlitPassDescriptor

#if DARLING_METAL_ENABLED

@synthesize sampleBufferAttachments = _sampleBufferAttachments;

+ (MTLBlitPassDescriptor*)blitPassDescriptor
{
	return [[[MTLBlitPassDescriptor alloc] init] autorelease];
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_sampleBufferAttachments = [MTLBlitPassSampleBufferAttachmentDescriptorArray new];
	}
	return self;
}

- (void)dealloc
{
	[_sampleBufferAttachments release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLBlitPassDescriptor* copy = [[MTLBlitPassDescriptor allocWithZone: zone] init];
	[copy->_sampleBufferAttachments release];
	copy->_sampleBufferAttachments = [_sampleBufferAttachments copy];
	return copy;
}

#else

@dynamic sampleBufferAttachments;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLBlitPassDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::BlitPassDescriptor)asIndiumDescriptor
{
	return Indium::BlitPassDescriptor {
		[_sampleBufferAttachments asIndiumAttachments],
	};
}

#endif

@end
