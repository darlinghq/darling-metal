// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLCommandQueueInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/MTLCommandBufferInternal.h>
#import <Metal/stubs.h>

@implementation MTLCommandQueueInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::CommandQueue> _queue;
}

@synthesize device = _device;
@synthesize label = _label;

- (instancetype)initWithQueue: (std::shared_ptr<Indium::CommandQueue>)queue
                       device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_queue = queue;
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

- (id<MTLCommandBuffer>)commandBuffer
{
	auto buf = _queue->commandBuffer();
	if (!buf) {
		return nil;
	}
	return [[[MTLCommandBufferInternal alloc] initWithCommandBuffer: buf commandQueue: self] autorelease];
}

- (id<MTLCommandBuffer>)commandBufferWithUnretainedReferences
{
	auto buf = _queue->commandBuffer();
	if (!buf) {
		return nil;
	}
	return [[[MTLCommandBufferInternal alloc] initWithCommandBuffer: buf commandQueue: self retainedReferences: NO errorOptions: MTLCommandBufferErrorOptionNone] autorelease];
}

- (id<MTLCommandBuffer>)commandBufferWithDescriptor: (MTLCommandBufferDescriptor*)descriptor
{
	if (descriptor == nil) {
		return nil;
	}
	auto buf = _queue->commandBuffer();
	if (!buf) {
		return nil;
	}
	return [[[MTLCommandBufferInternal alloc] initWithCommandBuffer: buf commandQueue: self retainedReferences: descriptor.retainedReferences errorOptions: descriptor.errorOptions] autorelease];
}

// Vulkan keeps all memory resident, and residency sets do not track hazards: there is nothing to do.

- (void)addResidencySet: (id<MTLResidencySet>)residencySet
{
}

- (void)addResidencySets: (const id<MTLResidencySet> __nonnull[__nonnull])residencySets
                   count: (NSUInteger)count
{
}

- (void)removeResidencySet: (id<MTLResidencySet>)residencySet
{
}

- (void)removeResidencySets: (const id<MTLResidencySet> __nonnull[__nonnull])residencySets
                      count: (NSUInteger)count
{
}

#else

@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
