/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Metal/MTLComputeCommandEncoderInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLComputePipelineInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/stubs.h>

@implementation MTLComputePassSampleBufferAttachmentDescriptor

#if DARLING_METAL_ENABLED

- (id)copyWithZone: (NSZone*)zone
{
	MTLComputePassSampleBufferAttachmentDescriptor* copy = [[MTLComputePassSampleBufferAttachmentDescriptor alloc] init];
	copy.sampleBuffer = self.sampleBuffer;
	copy.startOfEncoderSampleIndex = self.startOfEncoderSampleIndex;
	copy.endOfEncoderSampleIndex = self.endOfEncoderSampleIndex;
	return copy;
}

- (void)dealloc
{
	// XXX: remove the cast once we introduce a protocol definition for MTLCounterSampleBuffer
	[(id<NSObject>)_sampleBuffer release];
	[super dealloc];
}

#else

@dynamic sampleBuffer;
@dynamic startOfEncoderSampleIndex;
@dynamic endOfEncoderSampleIndex;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLComputePassSampleBufferAttachmentDescriptorArray

#if DARLING_METAL_ENABLED

{
	NSMutableDictionary<NSNumber*, MTLComputePassSampleBufferAttachmentDescriptor*>* _dict;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_dict = [NSMutableDictionary new];
	}
	return self;
}

- (instancetype)initWithDictionary: (NSDictionary<NSNumber*, MTLComputePassSampleBufferAttachmentDescriptor*>*)dictionary
{
	self = [super init];
	if (self != nil) {
		_dict = [dictionary mutableCopy];
	}
	return self;
}

- (void)dealloc
{
	[_dict release];
	[super dealloc];
}

- (MTLComputePassSampleBufferAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)index
{
	if (!_dict[@(index)]) {
		_dict[@(index)] = [[MTLComputePassSampleBufferAttachmentDescriptor new] autorelease];
	}
	return [[_dict[@(index)] retain] autorelease];
}

-    (void)setObject: (MTLComputePassSampleBufferAttachmentDescriptor*)desc
  atIndexedSubscript: (NSUInteger)index
{
	_dict[@(index)] = desc;
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLComputePassSampleBufferAttachmentDescriptorArray (Internal)

#if DARLING_METAL_ENABLED

- (id)copyWithZone: (NSZone*)zone
{
	return [[MTLComputePassSampleBufferAttachmentDescriptorArray alloc] initWithDictionary: _dict];
}

#endif

@end

@implementation MTLComputePassDescriptor

#if DARLING_METAL_ENABLED

+ (MTLComputePassDescriptor*)computePassDescriptor
{
	return [[[MTLComputePassDescriptor alloc] init] autorelease];
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_dispatchType = MTLDispatchTypeSerial;
		_sampleBufferAttachments = [MTLComputePassSampleBufferAttachmentDescriptorArray new];
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
	MTLComputePassDescriptor* copy = [[MTLComputePassDescriptor alloc] init];
	copy.dispatchType = self.dispatchType;
	_sampleBufferAttachments = [_sampleBufferAttachments copy];
	return copy;
}

#else

@dynamic dispatchType;
@dynamic sampleBufferAttachments;

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLComputePassDescriptor (Internal)

#if DARLING_METAL_ENABLED

- (Indium::ComputePassDescriptor)asIndiumDescriptor
{
	return Indium::ComputePassDescriptor {
		{}, // TODO
		static_cast<Indium::DispatchType>(_dispatchType),
	};
}

#endif

@end

@implementation MTLComputeCommandEncoderInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::ComputeCommandEncoder> _encoder;
}

@synthesize device = _device;
@synthesize label = _label;

- (instancetype)initWithEncoder: (std::shared_ptr<Indium::ComputeCommandEncoder>)encoder
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

- (void)endEncoding
{
	_encoder->endEncoding();
}

- (MTLDispatchType)dispatchType
{
	return static_cast<MTLDispatchType>(_encoder->dispatchType());
}

- (void)setComputePipelineState:(id<MTLComputePipelineState>)state
{
	// XXX: do we need to retain the ObjC state object? i.e. is it required by the API/ABI?
	_encoder->setComputePipelineState(((MTLComputePipelineStateInternal*)state).state);
}

- (void)setBuffer: (id<MTLBuffer>)buffer
           offset: (NSUInteger)offset
          atIndex: (NSUInteger)index
{
	_encoder->setBuffer(((MTLBufferInternal*)buffer).buffer, offset, index);
}

- (void)setBuffers: (const id<MTLBuffer>*)buffers
           offsets: (const NSUInteger *)offsets
         withRange: (NSRange)range
{
	// TODO: add a raw array version of this method in Indium to avoid creating a vector here
	std::vector<std::shared_ptr<Indium::Buffer>> indiumBuffers;
	std::vector<size_t> indiumOffsets;
	for (size_t i = 0; i < range.length; ++i) {
		indiumBuffers.push_back(((MTLBufferInternal*)buffers[i]).buffer);
		indiumOffsets.push_back(offsets[i]);
	}
	_encoder->setBuffers(indiumBuffers, indiumOffsets, NSRangeToIndium(range));
}

- (void)setBufferOffset: (NSUInteger)offset
                atIndex: (NSUInteger)index
{
	_encoder->setBufferOffset(offset, index);
}

- (void)setBytes: (const void*)bytes
          length: (NSUInteger)length
         atIndex: (NSUInteger)index
{
	_encoder->setBytes(bytes, length, index);
}

- (void)dispatchThreadgroups: (MTLSize)threadgroupsPerGrid
       threadsPerThreadgroup: (MTLSize)threadsPerThreadgroup
{
	_encoder->dispatchThreadgroups(MTLSizeToIndium(threadgroupsPerGrid), MTLSizeToIndium(threadsPerThreadgroup));
}

- (void)dispatchThreads: (MTLSize)threadsPerGrid 
  threadsPerThreadgroup: (MTLSize)threadsPerThreadgroup
{
	_encoder->dispatchThreads(MTLSizeToIndium(threadsPerGrid), MTLSizeToIndium(threadsPerThreadgroup));
}

#else

@dynamic dispatchType;
@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
