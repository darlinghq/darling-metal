// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>

@implementation MTLBufferInternal

#if DARLING_METAL_ENABLED

@synthesize buffer = _buffer;

const std::shared_ptr<Indium::Buffer>& MTLBufferGetIndium(id<MTLBuffer> object)
{
	static const std::shared_ptr<Indium::Buffer> none;
	static const Class internalClass = [MTLBufferInternal class];

	if (!MTLObjectIsInstanceOf(object, internalClass)) {
		return none;
	}
	return ((MTLBufferInternal*)object)->_buffer;
}
@synthesize device = _device;
@synthesize resourceOptions = _resourceOptions;
@synthesize label = _label;

- (instancetype)initWithBuffer: (std::shared_ptr<Indium::Buffer>)buffer
                        device: (id<MTLDevice>)device
               resourceOptions: (MTLResourceOptions)options
{
	self = [super init];
	if (self != nil) {
		_buffer = buffer;
		_device = [device retain];
		_resourceOptions = options;
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[super dealloc];
}

- (NSUInteger)length
{
	return _buffer->length();
}

- (uint64_t)gpuAddress
{
	return _buffer->gpuAddress();
}

- (void*)contents
{
	return _buffer->contents();
}

- (void)didModifyRange: (NSRange)range
{
	return _buffer->didModifyRange(NSRangeToIndium(range));
}

- (MTLCPUCacheMode)cpuCacheMode
{
	return static_cast<MTLCPUCacheMode>((self.resourceOptions >> MTLResourceCPUCacheModeShift) & 0x0f);
}

- (MTLStorageMode)storageMode
{
	return static_cast<MTLStorageMode>((self.resourceOptions >> MTLResourceStorageModeShift) & 0x0f);
}

- (MTLHazardTrackingMode)hazardTrackingMode
{
	return static_cast<MTLHazardTrackingMode>((self.resourceOptions >> MTLResourceHazardTrackingModeShift) & 0x0f);
}

#else

@dynamic length;
@dynamic gpuAddress;
@dynamic device;
@dynamic cpuCacheMode;
@dynamic storageMode;
@dynamic hazardTrackingMode;
@dynamic resourceOptions;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
