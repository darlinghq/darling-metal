// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLCountersInternal.h>
#import <Metal/MTLTypesInternal.h>

// The names are the strings the common counters and counter sets are known by.
MTLCommonCounter MTLCommonCounterTimestamp = @"GPUTimestamp";
MTLCommonCounter MTLCommonCounterTessellationInputPatches = @"TessellationInputPatches";
MTLCommonCounter MTLCommonCounterVertexInvocations = @"VertexInvocations";
MTLCommonCounter MTLCommonCounterPostTessellationVertexInvocations = @"PostTessellationVertexInvocations";
MTLCommonCounter MTLCommonCounterClipperInvocations = @"ClipperInvocations";
MTLCommonCounter MTLCommonCounterClipperPrimitivesOut = @"ClipperPrimitivesOut";
MTLCommonCounter MTLCommonCounterFragmentInvocations = @"FragmentInvocations";
MTLCommonCounter MTLCommonCounterFragmentsPassed = @"FragmentsPassed";
MTLCommonCounter MTLCommonCounterComputeKernelInvocations = @"KernelInvocations";
MTLCommonCounter MTLCommonCounterTotalCycles = @"TotalCycles";
MTLCommonCounter MTLCommonCounterVertexCycles = @"VertexCycles";
MTLCommonCounter MTLCommonCounterTessellationCycles = @"TessellationCycles";
MTLCommonCounter MTLCommonCounterPostTessellationVertexCycles = @"PostTessellationCycles";
MTLCommonCounter MTLCommonCounterFragmentCycles = @"FragmentCycles";
MTLCommonCounter MTLCommonCounterRenderTargetWriteCycles = @"RenderTargetWriteCycles";

MTLCommonCounterSet MTLCommonCounterSetTimestamp = @"timestamp";
MTLCommonCounterSet MTLCommonCounterSetStageUtilization = @"stageutilization";
MTLCommonCounterSet MTLCommonCounterSetStatistic = @"statistic";

NSErrorDomain const MTLCounterErrorDomain = @"MTLCounterErrorDomain";

#if __LP64__


@implementation MTLCounterSampleBufferDescriptor

@synthesize label = _label;
@synthesize counterSet = _counterSet;
@synthesize storageMode = _storageMode;
@synthesize sampleCount = _sampleCount;

- (void)dealloc
{
	[_label release];
	[(id)_counterSet release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLCounterSampleBufferDescriptor* copy =
		[[MTLCounterSampleBufferDescriptor allocWithZone: zone] init];

	copy.label = _label;
	copy.counterSet = _counterSet;
	copy.storageMode = _storageMode;
	copy.sampleCount = _sampleCount;

	return copy;
}

@end

@implementation MTLCounterInternal

@synthesize name = _name;

- (instancetype)initWithName: (NSString*)name
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
	}
	return self;
}

- (void)dealloc
{
	[_name release];
	[super dealloc];
}

@end

@implementation MTLCounterSetInternal

@synthesize name = _name;
@synthesize counters = _counters;

- (instancetype)initWithName: (NSString*)name counters: (NSArray<id<MTLCounter>>*)counters
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
		_counters = [counters copy];
	}
	return self;
}

- (void)dealloc
{
	[_name release];
	[_counters release];
	[super dealloc];
}

@end

@implementation MTLCounterSampleBufferInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::CounterSampleBuffer> _sampleBuffer;
}

@synthesize device = _device;
@synthesize label = _label;

std::shared_ptr<Indium::CounterSampleBuffer> MTLCounterSampleBufferGetIndium(id<MTLCounterSampleBuffer> object)
{
	static const Class internalClass = [MTLCounterSampleBufferInternal class];

	if (!MTLObjectIsInstanceOf(object, internalClass)) {
		return nullptr;
	}
	return ((MTLCounterSampleBufferInternal*)object)->_sampleBuffer;
}

- (instancetype)initWithSampleBuffer: (std::shared_ptr<Indium::CounterSampleBuffer>)sampleBuffer
                              device: (id<MTLDevice>)device
                               label: (NSString*)label
{
	self = [super init];
	if (self != nil) {
		_sampleBuffer = sampleBuffer;
		_device = [device retain];
		_label = [label copy];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[super dealloc];
}

- (NSUInteger)sampleCount
{
	return _sampleBuffer->sampleCount();
}

- (NSData*)resolveCounterRange: (NSRange)range
{
	auto bytes = _sampleBuffer->resolveCounterRange({ range.location, range.length });
	if (bytes.empty()) {
		return nil;
	}
	return [NSData dataWithBytes: bytes.data() length: bytes.size()];
}

#else

@dynamic device;
@dynamic label;
@dynamic sampleCount;

- (NSData*)resolveCounterRange: (NSRange)range
{
	return nil;
}

#endif

@end

#endif // __LP64__
