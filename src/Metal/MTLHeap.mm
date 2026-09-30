// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLHeap.h>

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
