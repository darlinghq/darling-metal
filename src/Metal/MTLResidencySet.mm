// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLResidencySetInternal.h>
#import <Metal/MTLResource.h>

#if __LP64__


@implementation MTLResidencySetDescriptor

@synthesize label = _label;
@synthesize initialCapacity = _initialCapacity;

- (void)dealloc
{
	[_label release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLResidencySetDescriptor* copy = [[MTLResidencySetDescriptor allocWithZone: zone] init];

	copy.label = _label;
	copy.initialCapacity = _initialCapacity;

	return copy;
}

@end

@implementation MTLResidencySetInternal
{
	// the allocations as of the last commit, and as they will be after the next one
	NSOrderedSet* _committed;
	NSMutableOrderedSet* _staged;
	uint64_t _allocatedSize;
}

@synthesize device = _device;
@synthesize label = _label;
@synthesize allocatedSize = _allocatedSize;

- (instancetype)initWithDevice: (id<MTLDevice>)device
                         label: (NSString*)label
               initialCapacity: (NSUInteger)initialCapacity
{
	self = [super init];
	if (self != nil) {
		_device = [device retain];
		_label = [label copy];
		_committed = [NSOrderedSet new];
		_staged = [[NSMutableOrderedSet alloc] initWithCapacity: initialCapacity];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[_committed release];
	[_staged release];
	[super dealloc];
}

// allAllocations, containsAllocation: and allocationCount include the staged additions, as Apple's MTLResidencySet.h
// says (the online documentation says they change on -commit).

- (NSArray<id<MTLAllocation>>*)allAllocations
{
	return [[_staged.array copy] autorelease];
}

- (NSUInteger)allocationCount
{
	// QUIRK: allocations staged to be removed still count until -commit, so the count can exceed the number of
	// elements of allAllocations. Not documented. Evidence: black-box observation on macOS 27.0 (Apple M1), tier 2.
	// Applications that check the count between staging and committing see the numbers macOS gives them.
	// Test: "staged changes" in test/guest/residency_sets.m.
	NSUInteger count = _committed.count;
	for (id allocation in _staged) {
		if (![_committed containsObject: allocation]) {
			count++;
		}
	}
	return count;
}

- (BOOL)containsAllocation: (id<MTLAllocation>)allocation
{
	return [_staged containsObject: allocation];
}

- (void)addAllocation: (id<MTLAllocation>)allocation
{
	if (allocation) {
		[_staged addObject: allocation];
	}
}

- (void)addAllocations: (const id<MTLAllocation> __nonnull[__nonnull])allocations
                 count: (NSUInteger)count
{
	for (NSUInteger i = 0; i < count; i++) {
		[self addAllocation: allocations[i]];
	}
}

- (void)removeAllocation: (id<MTLAllocation>)allocation
{
	if (allocation) {
		[_staged removeObject: allocation];
	}
}

- (void)removeAllocations: (const id<MTLAllocation> __nonnull[__nonnull])allocations
                    count: (NSUInteger)count
{
	for (NSUInteger i = 0; i < count; i++) {
		[self removeAllocation: allocations[i]];
	}
}

- (void)removeAllAllocations
{
	[_staged removeAllObjects];
}

- (void)commit
{
	// Releasing the previous allocations can deallocate some of them, and their deallocators may use the set: it is
	// updated first.
	NSOrderedSet* previous = _committed;
	_committed = [_staged copy];

	// a resource made from a heap makes the whole heap resident
	NSMutableSet* counted = [NSMutableSet set];
	uint64_t size = 0;
	for (id<MTLAllocation> allocation in _committed) {
		id<MTLAllocation> memory = allocation;
		if ([allocation conformsToProtocol: @protocol(MTLResource)] && ((id<MTLResource>)allocation).heap) {
			memory = (id<MTLAllocation>)((id<MTLResource>)allocation).heap;
		}
		if (![counted containsObject: memory]) {
			[counted addObject: memory];
			size += memory.allocatedSize;
		}
	}
	_allocatedSize = size;
	[previous release];
}

- (void)requestResidency
{
}

- (void)endResidency
{
}

@end

#endif // __LP64__
