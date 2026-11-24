// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLHeapInternal.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLTextureDescriptorInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>

#if __LP64__


// resourceOptions is not stored. Apple documents the two views as reflecting
// each other, and deriving the packed value from the three mode properties is
// the only way to keep that true without a second copy that can go stale: a
// caller that sets storageMode and then reads resourceOptions has to see the
// storage mode in it, and one that sets resourceOptions and then reads
// storageMode has to see the storage mode in that.
static MTLResourceOptions MTLHeapDescriptorResourceOptions(MTLHeapDescriptor* descriptor)
{
	return (MTLResourceOptions)(((NSUInteger)descriptor.cpuCacheMode << MTLResourceCPUCacheModeShift)
		| ((NSUInteger)descriptor.storageMode << MTLResourceStorageModeShift)
		| ((NSUInteger)descriptor.hazardTrackingMode << MTLResourceHazardTrackingModeShift));
}

@implementation MTLHeapDescriptor

@synthesize size = _size;
@synthesize type = _type;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		// a heap descriptor starts out private, unlike the other descriptors
		_storageMode = MTLStorageModePrivate;
	}
	return self;
}

- (MTLResourceOptions)resourceOptions
{
	return MTLHeapDescriptorResourceOptions(self);
}

- (void)setResourceOptions: (MTLResourceOptions)resourceOptions
{
	_cpuCacheMode = (MTLCPUCacheMode)((resourceOptions >> MTLResourceCPUCacheModeShift) & 0x3);
	_storageMode = (MTLStorageMode)((resourceOptions >> MTLResourceStorageModeShift) & 0x3);
	_hazardTrackingMode = (MTLHazardTrackingMode)((resourceOptions >> MTLResourceHazardTrackingModeShift) & 0x3);
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLHeapDescriptor* copy = [[MTLHeapDescriptor allocWithZone: zone] init];

	copy.size = _size;
	copy.storageMode = _storageMode;
	copy.cpuCacheMode = _cpuCacheMode;
	copy.hazardTrackingMode = _hazardTrackingMode;
	copy.type = _type;

	return copy;
}

@end

@implementation MTLHeapInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::Heap> _heap;
	id<MTLDevice> _device;
	NSString* _label;
	MTLPurgeableState _purgeableState;
	NSLock* _purgeableLock;
}

@synthesize device = _device;
@synthesize label = _label;

const std::shared_ptr<Indium::Heap>& MTLHeapGetIndium(id<MTLHeap> object)
{
	static const std::shared_ptr<Indium::Heap> none;
	static const Class internalClass = [MTLHeapInternal class];

	if (!MTLObjectIsInstanceOf(object, internalClass)) {
		return none;
	}
	return ((MTLHeapInternal*)object)->_heap;
}

- (instancetype)initWithHeap: (std::shared_ptr<Indium::Heap>)heap
                      device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_heap = heap;
		_device = [device retain];
		_purgeableState = MTLPurgeableStateNonVolatile;
		_purgeableLock = [[NSLock alloc] init];
	}
	return self;
}

- (void)dealloc
{
	// the memory goes with the Indium heap, which the resources made from it keep alive as well
	_heap.reset();
	[_purgeableLock release];
	[_device release];
	[_label release];
	[super dealloc];
}

- (MTLStorageMode)storageMode
{
	return static_cast<MTLStorageMode>(_heap->storageMode());
}

- (MTLCPUCacheMode)cpuCacheMode
{
	return static_cast<MTLCPUCacheMode>(_heap->cpuCacheMode());
}

- (MTLHazardTrackingMode)hazardTrackingMode
{
	return static_cast<MTLHazardTrackingMode>(_heap->hazardTrackingMode());
}

- (MTLResourceOptions)resourceOptions
{
	return (MTLResourceOptions)(((NSUInteger)self.cpuCacheMode << MTLResourceCPUCacheModeShift)
		| ((NSUInteger)self.storageMode << MTLResourceStorageModeShift)
		| ((NSUInteger)self.hazardTrackingMode << MTLResourceHazardTrackingModeShift));
}

- (MTLHeapType)type
{
	return static_cast<MTLHeapType>(_heap->type());
}

- (NSUInteger)size
{
	return _heap->size();
}

- (NSUInteger)usedSize
{
	return _heap->usedSize();
}

- (NSUInteger)currentAllocatedSize
{
	return _heap->currentAllocatedSize();
}

- (NSUInteger)allocatedSize
{
	return _heap->size();
}

- (NSUInteger)maxAvailableSizeWithAlignment: (NSUInteger)alignment
{
	return _heap->maxAvailableSize(alignment);
}

- (MTLPurgeableState)setPurgeableState: (MTLPurgeableState)state
{
	[_purgeableLock lock];
	MTLPurgeableState previous = _purgeableState;
	if (state != MTLPurgeableStateKeepCurrent) {
		_purgeableState = state;
	}
	[_purgeableLock unlock];
	return previous;
}

- (id<MTLBuffer>)wrapBuffer: (std::shared_ptr<Indium::Buffer>)buffer
{
	if (!buffer) {
		return nil;
	}
	MTLBufferInternal* result = [[MTLBufferInternal alloc] initWithBuffer: buffer device: _device resourceOptions: self.resourceOptions];
	result.owningHeap = self;
	return result;
}

- (id<MTLTexture>)wrapTexture: (std::shared_ptr<Indium::Texture>)texture
{
	if (!texture) {
		return nil;
	}
	MTLTextureInternal* result = [[MTLTextureInternal alloc] initWithTexture: texture device: _device resourceOptions: self.resourceOptions];
	result.owningHeap = self;
	return result;
}

- (id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                             options: (MTLResourceOptions)options
{
	// the heap refuses (nil) what it cannot place; a device failure is an exception from Indium
	try {
		return [self wrapBuffer: _heap->newBuffer(length, static_cast<Indium::ResourceOptions>(options))];
	} catch (const std::exception&) {
		return nil;
	}
}

- (id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                             options: (MTLResourceOptions)options
                              offset: (NSUInteger)offset
{
	try {
		return [self wrapBuffer: _heap->newBuffer(length, static_cast<Indium::ResourceOptions>(options), offset)];
	} catch (const std::exception&) {
		return nil;
	}
}

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor
{
	if (descriptor == nil) {
		return nil;
	}
	try {
		return [self wrapTexture: _heap->newTexture([descriptor asIndiumDescriptor])];
	} catch (const std::exception&) {
		return nil;
	}
}

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor
                                    offset: (NSUInteger)offset
{
	if (descriptor == nil) {
		return nil;
	}
	try {
		return [self wrapTexture: _heap->newTexture([descriptor asIndiumDescriptor], offset)];
	} catch (const std::exception&) {
		return nil;
	}
}

#else

@dynamic device;
@dynamic storageMode;
@dynamic cpuCacheMode;
@dynamic hazardTrackingMode;
@dynamic resourceOptions;
@dynamic type;
@dynamic size;
@dynamic usedSize;
@dynamic currentAllocatedSize;
@dynamic allocatedSize;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end

#endif // __LP64__
