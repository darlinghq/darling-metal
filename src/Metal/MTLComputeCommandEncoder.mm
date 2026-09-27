// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLComputeCommandEncoderInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLComputePipelineInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLSamplerStateInternal.h>
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

- (void)setStageInRegion:(MTLRegion)region
{
	_encoder->setStageInRegion(MTLRegionToIndium(region));
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

- (void)setTexture: (id<MTLTexture>)texture
          atIndex: (NSUInteger)index
{
	_encoder->setTexture(((MTLTextureInternal*)texture).texture, index);
}

- (void)setTextures: (const id<MTLTexture>*)textures
          withRange: (NSRange)range
{
	std::vector<std::shared_ptr<Indium::Texture>> indiumTextures;
	for (size_t i = 0; i < range.length; ++i) {
		indiumTextures.push_back(((MTLTextureInternal*)textures[i]).texture);
	}
	_encoder->setTextures(indiumTextures, NSRangeToIndium(range));
}

- (void)setSamplerState: (id<MTLSamplerState>)sampler
                atIndex: (NSUInteger)index
{
	_encoder->setSamplerState(((MTLSamplerStateInternal*)sampler).state, index);
}

- (void)setSamplerStates: (const id<MTLSamplerState>*)samplers
                withRange: (NSRange)range
{
	std::vector<std::shared_ptr<Indium::SamplerState>> indiumSamplers;
	for (size_t i = 0; i < range.length; ++i) {
		indiumSamplers.push_back(((MTLSamplerStateInternal*)samplers[i]).state);
	}
	_encoder->setSamplerStates(indiumSamplers, NSRangeToIndium(range));
}

- (void)setSamplerState: (id<MTLSamplerState>)sampler
             lodMinClamp: (float)lodMinClamp
             lodMaxClamp: (float)lodMaxClamp
                atIndex: (NSUInteger)index
{
	_encoder->setSamplerState(((MTLSamplerStateInternal*)sampler).state, lodMinClamp, lodMaxClamp, index);
}

- (void)setSamplerStates: (const id<MTLSamplerState>*)samplers
             lodMinClamps: (const float*)lodMinClamps
             lodMaxClamps: (const float*)lodMaxClamps
                withRange: (NSRange)range
{
	std::vector<std::shared_ptr<Indium::SamplerState>> indiumSamplers;
	for (size_t i = 0; i < range.length; ++i) {
		indiumSamplers.push_back(((MTLSamplerStateInternal*)samplers[i]).state);
	}
	_encoder->setSamplerStates(indiumSamplers, std::vector<float>(lodMinClamps, lodMinClamps + range.length), std::vector<float>(lodMaxClamps, lodMaxClamps + range.length), NSRangeToIndium(range));
}

- (void)setThreadgroupMemoryLength: (NSUInteger)length
                          atIndex: (NSUInteger)index
{
	_encoder->setThreadgroupMemoryLength(length, index);
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
