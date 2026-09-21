// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLDeviceInternal.h>
#import <dispatch/dispatch.h>
#import <Metal/MTLLibraryInternal.h>
#import <Metal/MTLComputePipelineInternal.h>
#import <Metal/MTLCommandQueueInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLLibraryInternal.h>
#import <Metal/stubs.h>
#import <Metal/MTLRenderPipelineInternal.h>
#import <Metal/MTLTextureDescriptorInternal.h>
#import <Metal/MTLTextureInternal.h>

MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasAddedNotification = @"MTLDeviceWasAdded";
MTL_EXTERN const MTLDeviceNotificationName MTLDeviceRemovalRequestedNotification = @"MTLDeviceRemovalRequested";
MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasRemovedNotification = @"MTLDeviceWasRemoved";

#if DARLING_METAL_ENABLED

static NSMutableArray<MTLDeviceInternal*>* devices = nil;
static dispatch_once_t devicesInitToken = 0;
static MTLDeviceInternal* systemDefaultDevice = nil;

static void ensureDevices(void) {
	dispatch_once(&devicesInitToken, ^{
		devices = [NSMutableArray new];

		// for now, we just have the system default device
		auto indiumDevice = Indium::createSystemDefaultDevice();
		if (indiumDevice) {
			systemDefaultDevice = [[MTLDeviceInternal alloc] initWithDevice: indiumDevice];

			[devices addObject: systemDefaultDevice];
		}
	});
};

void MTLDeviceDestroyAll(void) {
	for (MTLDeviceInternal* device in devices) {
		[device stopPolling];
		[device waitUntilPollingIsStopped];
	}

	if (systemDefaultDevice) {
		[systemDefaultDevice release];
	}

	if (devices) {
		[devices release];
	}
};

#endif

MTL_EXTERN
id<MTLDevice> MTLCreateSystemDefaultDevice(void) {
#if DARLING_METAL_ENABLED
	ensureDevices();
	if (systemDefaultDevice) {
		return [systemDefaultDevice retain];
	}
#endif
	return nil;
};

MTL_EXTERN
NSArray<id<MTLDevice>>* MTLCopyAllDevices(void) {
#if DARLING_METAL_ENABLED
	ensureDevices();
	return [devices copy];
#else
	return [NSArray new];
#endif
};

MTL_EXTERN
NSArray<id<MTLDevice>>* MTLCopyAllDevicesWithObserver(id<NSObject>* observer, MTLDeviceNotificationHandler handler) {
	// TODO: actually use observer
	if (observer) {
		*observer = [NSObject new];
	}
	return MTLCopyAllDevices();
};

MTL_EXTERN
void MTLRemoveDeviceObserver(id<NSObject> observer) {
	// TODO: actually use observer
	[observer release];
};

@implementation MTLDeviceInternal

#if DARLING_METAL_ENABLED

{
	NSThread* _pollingThread;
	NSCondition* _threadExitCondition;
	BOOL _threadIsRunning;
}

@synthesize device = _device;

- (void)pollingLoop
{
	[_threadExitCondition lock];
	_threadIsRunning = YES;
	[_threadExitCondition unlock];

	while (!_pollingThread.isCancelled) {
		_device->pollEvents(UINT64_MAX);
	}

	[_threadExitCondition lock];
	_threadIsRunning = NO;
	[_threadExitCondition broadcast];
	[_threadExitCondition unlock];
}

- (instancetype)initWithDevice: (std::shared_ptr<Indium::Device>)device
{
	self = [super init];
	if (self != nil) {
		_device = device;
		_threadExitCondition = [NSCondition new];
		_threadIsRunning = NO;
		_pollingThread = [[NSThread alloc] initWithTarget: self selector: @selector(pollingLoop) object: nil];
		[_pollingThread start];
	}
	return self;
}

- (void)dealloc
{
	[_pollingThread release];
	[_threadExitCondition release];

	[super dealloc];
}

- (void)stopPolling
{
	[_pollingThread cancel];
	_device->wakeupEventLoop();
}

- (void)waitUntilPollingIsStopped
{
	// wait for the polling thread to die
	[_threadExitCondition lock];
	while (_threadIsRunning) {
		[_threadExitCondition wait];
	}
	[_threadExitCondition unlock];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithDescriptor: (MTLComputePipelineDescriptor*)descriptor
                                                             options: (MTLPipelineOption)options
                                                          reflection: (MTLAutoreleasedComputePipelineReflection*)reflection
                                                               error: (NSError**)error
{
	auto pso = _device->newComputePipelineState(descriptor.asIndiumDescriptor, static_cast<Indium::PipelineOption>(options), nullptr);
	if (!pso) {
		if (error) {
			// TODO: better error and/or match what the official Metal method does
			*error = [NSError errorWithDomain: NSPOSIXErrorDomain code: ENOMEM userInfo: nil];
		}
		return nil;
	}
	return [[MTLComputePipelineStateInternal alloc] initWithState: pso device: self label: descriptor.label];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction 
                                                             error: (NSError**)error
{
	return [self newComputePipelineStateWithFunction: computeFunction
	                                         options: MTLPipelineOptionNone
	                                      reflection: nil
	                                           error: error];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction 
                                                           options: (MTLPipelineOption)options 
                                                        reflection: (MTLAutoreleasedComputePipelineReflection*)reflection 
                                                             error: (NSError**)error
{
	auto pso = _device->newComputePipelineState(((MTLFunctionInternal*)computeFunction).function, static_cast<Indium::PipelineOption>(options), nullptr);
	if (!pso) {
		if (error) {
			// TODO: better error and/or match what the official Metal method does
			*error = [NSError errorWithDomain: NSPOSIXErrorDomain code: ENOMEM userInfo: nil];
		}
		return nil;
	}
	return [[MTLComputePipelineStateInternal alloc] initWithState: pso device: self label: nil];
}

- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                                             error: (NSError**)error
{
	auto pso = _device->newRenderPipelineState([descriptor asIndiumDescriptor]);
	if (!pso) {
		if (error) {
			// TODO: better error and/or match what the official Metal method does
			*error = [NSError errorWithDomain: NSPOSIXErrorDomain code: ENOMEM userInfo: nil];
		}
		return nil;
	}
	return [[MTLRenderPipelineStateInternal alloc] initWithState: pso device: self label: descriptor.label];
}

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor
{
	auto texture = _device->newTexture([descriptor asIndiumDescriptor]);
	if (!texture) {
		return nil;
	}
	return [[MTLTextureInternal alloc] initWithTexture: texture device: self resourceOptions: descriptor.resourceOptions];
}

- (id<MTLCommandQueue>)newCommandQueue
{
	auto queue = _device->newCommandQueue();
	if (!queue) {
		return nil;
	}
	return [[MTLCommandQueueInternal alloc] initWithQueue: queue device: self];
}

- (id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                             options: (MTLResourceOptions)options
{
	auto buf = _device->newBuffer(length, static_cast<Indium::ResourceOptions>(options));
	if (!buf) {
		return nil;
	}
	return [[MTLBufferInternal alloc] initWithBuffer: buf device: self resourceOptions: options];
}

- (id<MTLBuffer>)newBufferWithBytes: (const void*)pointer
                             length: (NSUInteger)length
                            options: (MTLResourceOptions)options
{
	auto buf = _device->newBuffer(pointer, length, static_cast<Indium::ResourceOptions>(options));
	if (!buf) {
		return nil;
	}
	return [[MTLBufferInternal alloc] initWithBuffer: buf device: self resourceOptions: options];
}

- (id<MTLLibrary>)newDefaultLibrary
{
	return [self newDefaultLibraryWithBundle: [NSBundle mainBundle] error: nil];
}

- (id<MTLLibrary>)newDefaultLibraryWithBundle: (NSBundle*)bundle
                                        error: (NSError**)error
{
	NSURL* url = [bundle URLForResource: @"default" withExtension: @"metallib"];
	if (url == nil) {
		if (error) {
			// TODO: better error
			*error = [NSError errorWithDomain: NSPOSIXErrorDomain code: ENOENT userInfo: nil];
		}
		return nil;
	}
	return [self newLibraryWithURL: url error: error];
}

- (id<MTLLibrary>)newLibraryWithURL: (NSURL*)url
                              error: (NSError**)error
{
	NSData* data = [NSData dataWithContentsOfURL: url options: 0 error: error];
	if (data == nil) {
		// error was already written
		return nil;
	}
	auto lib = _device->newLibrary(data.bytes, data.length);
	if (!lib) {
		return nil;
	}
	return [[MTLLibraryInternal alloc] initWithLibrary: lib device: self];
}

- (id<MTLLibrary>)newLibraryWithData: (dispatch_data_t)data
                               error: (NSError**)error
{
	NSData* nsdata = (NSData*)data;
	auto lib = _device->newLibrary(nsdata.bytes, nsdata.length);
	if (!lib) {
		return nil;
	}
	return [[MTLLibraryInternal alloc] initWithLibrary: lib device: self];
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
