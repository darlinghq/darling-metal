// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLComputeCommandEncoderInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLComputePipelineInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLCountersInternal.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLSamplerStateInternal.h>
#import <Metal/MTLFenceInternal.h>
#import <Metal/MTLResourceInternal.h>
#import <Metal/stubs.h>

@implementation MTLComputePassSampleBufferAttachmentDescriptor

#if DARLING_METAL_ENABLED

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		self.startOfEncoderSampleIndex = MTLCounterDontSample;
		self.endOfEncoderSampleIndex = MTLCounterDontSample;
	}
	return self;
}

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
	if (desc == nil) {
		[_dict removeObjectForKey: @(index)];
	} else {
		_dict[@(index)] = desc;
	}
}

- (std::unordered_map<size_t, Indium::ComputePassSampleBufferAttachmentDescriptor>)asIndiumAttachments
{
	__block std::unordered_map<size_t, Indium::ComputePassSampleBufferAttachmentDescriptor> result;
	[_dict enumerateKeysAndObjectsUsingBlock: ^(NSNumber* key, MTLComputePassSampleBufferAttachmentDescriptor* value, BOOL* stop) {
		if (value.sampleBuffer != nil) {
			result[key.unsignedIntegerValue] = Indium::ComputePassSampleBufferAttachmentDescriptor {
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
	[copy->_sampleBufferAttachments release];
	copy->_sampleBufferAttachments = [_sampleBufferAttachments copy];
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
		[_sampleBufferAttachments asIndiumAttachments],
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

- (MTLDispatchType)dispatchType
{
	return static_cast<MTLDispatchType>(_encoder->dispatchType());
}

- (void)updateFence: (id<MTLFence>)fence
{
	_encoder->updateFence(MTLFenceGetIndium(fence));
}

- (void)waitForFence: (id<MTLFence>)fence
{
	_encoder->waitForFence(MTLFenceGetIndium(fence));
}

- (void)setComputePipelineState:(id<MTLComputePipelineState>)state
{
	// XXX: do we need to retain the ObjC state object? i.e. is it required by the API/ABI?
	_encoder->setComputePipelineState(MTLComputePipelineStateGetIndium(state));
}

- (void)setStageInRegion:(MTLRegion)region
{
	_encoder->setStageInRegion(MTLRegionToIndium(region));
}

- (void)setBuffer: (id<MTLBuffer>)buffer
           offset: (NSUInteger)offset
          atIndex: (NSUInteger)index
{
	_encoder->setBuffer(MTLBufferGetIndium(buffer), offset, index);
}

- (void)setBuffers: (const id<MTLBuffer>*)buffers
           offsets: (const NSUInteger *)offsets
         withRange: (NSRange)range
{
	// TODO: add a raw array version of this method in Indium to avoid creating a vector here
	std::vector<std::shared_ptr<Indium::Buffer>> indiumBuffers;
	std::vector<size_t> indiumOffsets;
	for (size_t i = 0; i < range.length; ++i) {
		indiumBuffers.push_back(MTLBufferGetIndium(buffers[i]));
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
	_encoder->setTexture(MTLTextureGetIndium(texture), index);
}

- (void)setTextures: (const id<MTLTexture>*)textures
          withRange: (NSRange)range
{
	std::vector<std::shared_ptr<Indium::Texture>> indiumTextures;
	for (size_t i = 0; i < range.length; ++i) {
		indiumTextures.push_back(MTLTextureGetIndium(textures[i]));
	}
	_encoder->setTextures(indiumTextures, NSRangeToIndium(range));
}

- (void)setSamplerState: (id<MTLSamplerState>)sampler
                atIndex: (NSUInteger)index
{
	_encoder->setSamplerState(MTLSamplerStateGetIndium(sampler), index);
}

- (void)setSamplerStates: (const id<MTLSamplerState>*)samplers
                withRange: (NSRange)range
{
	std::vector<std::shared_ptr<Indium::SamplerState>> indiumSamplers;
	for (size_t i = 0; i < range.length; ++i) {
		indiumSamplers.push_back(MTLSamplerStateGetIndium(samplers[i]));
	}
	_encoder->setSamplerStates(indiumSamplers, NSRangeToIndium(range));
}

- (void)setSamplerState: (id<MTLSamplerState>)sampler
             lodMinClamp: (float)lodMinClamp
             lodMaxClamp: (float)lodMaxClamp
                atIndex: (NSUInteger)index
{
	_encoder->setSamplerState(MTLSamplerStateGetIndium(sampler), lodMinClamp, lodMaxClamp, index);
}

- (void)setSamplerStates: (const id<MTLSamplerState>*)samplers
             lodMinClamps: (const float*)lodMinClamps
             lodMaxClamps: (const float*)lodMaxClamps
                withRange: (NSRange)range
{
	std::vector<std::shared_ptr<Indium::SamplerState>> indiumSamplers;
	for (size_t i = 0; i < range.length; ++i) {
		indiumSamplers.push_back(MTLSamplerStateGetIndium(samplers[i]));
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
	// A function that cannot skip the threads beyond the grid (it has a barrier) cannot be dispatched over a
	// grid that is not a multiple of the threadgroup size. indium says so by throwing, and running the threads
	// past the grid would write outside what the application made room for, so the exception goes to the
	// caller as an Objective-C one instead of ending the process.
	try {
		_encoder->dispatchThreads(MTLSizeToIndium(threadsPerGrid), MTLSizeToIndium(threadsPerThreadgroup));
	} catch (const std::exception& e) {
		@throw [NSException exceptionWithName: NSInvalidArgumentException
		                               reason: [NSString stringWithUTF8String: e.what()]
		                             userInfo: nil];
	}
}

- (void)dispatchThreadgroupsWithIndirectBuffer: (id<MTLBuffer>)indirectBuffer
                          indirectBufferOffset: (NSUInteger)indirectBufferOffset
                         threadsPerThreadgroup: (MTLSize)threadsPerThreadgroup
{
	_encoder->dispatchThreadgroups(MTLBufferGetIndium(indirectBuffer), indirectBufferOffset, MTLSizeToIndium(threadsPerThreadgroup));
}

// Every resource is resident for the GPU, so the residency itself needs nothing. What the commands that follow
// reach through an argument buffer or a heap is not visible to Indium, so it is declared to the encoder, which
// orders the commands that use those resources. A resource that is not tracked gets no ordering from it.
- (void)useResource: (id<MTLResource>)resource
              usage: (MTLResourceUsage)usage
{
	if (auto indiumResource = MTLResourceGetIndium(resource)) {
		_encoder->useResource(std::move(indiumResource), static_cast<Indium::ResourceUsage>(usage));
	}
}

- (void)useResources: (const id<MTLResource> __nonnull [__nonnull])resources
               count: (NSUInteger)count
               usage: (MTLResourceUsage)usage
{
	_encoder->useResources(MTLResourcesGetIndium(resources, count), static_cast<Indium::ResourceUsage>(usage));
}

- (void)useHeap: (id<MTLHeap>)heap
{
	if (auto& indiumHeap = MTLHeapGetIndium(heap)) {
		_encoder->useHeap(indiumHeap);
	}
}

- (void)useHeaps: (const id<MTLHeap> __nonnull [__nonnull])heaps
           count: (NSUInteger)count
{
	_encoder->useHeaps(MTLHeapsGetIndium(heaps, count));
}

// MTLBarrierScope has the same bit values as Indium's BarrierScope.
- (void)memoryBarrierWithScope: (MTLBarrierScope)scope
{
	_encoder->memoryBarrier(static_cast<Indium::BarrierScope>(scope));
}

- (void)memoryBarrierWithResources: (const id<MTLResource> __nonnull [__nonnull])resources
                             count: (NSUInteger)count
{
	_encoder->memoryBarrier(MTLResourcesGetIndium(resources, count));
}

#else

@dynamic dispatchType;
@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
