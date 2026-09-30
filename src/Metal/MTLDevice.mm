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
#import <Metal/MTLIndiumErrors.h>
#import <Metal/MTLArgumentInternal.h>
#import <Metal/MTLTextureDescriptorInternal.h>
#import <Metal/MTLTextureInternal.h>
#import <IOSurface/IOSurfaceRef.h>
#import <IOSurface/IOSurfacePriv.h>
#import <Metal/MTLSamplerDescriptorInternal.h>
#import <Metal/MTLSamplerStateInternal.h>
#import <Metal/MTLDepthStencilDescriptorInternal.h>
#import <Metal/MTLDeviceInfo.h>
#import <Metal/MTLMSLReflection.h>

#include <mslc/mslc.h>

#include <stdlib.h>
#include <string.h>
#include <string>

MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasAddedNotification = @"MTLDeviceWasAdded";
MTL_EXTERN const MTLDeviceNotificationName MTLDeviceRemovalRequestedNotification = @"MTLDeviceRemovalRequested";
MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasRemovedNotification = @"MTLDeviceWasRemoved";

#if DARLING_METAL_ENABLED

static NSMutableArray<MTLDeviceInternal*>* devices = nil;
static dispatch_once_t devicesInitToken = 0;
static MTLDeviceInternal* systemDefaultDevice = nil;

// Platform identity settings (org.darlinghq.platform, as for the rest of the system's identity).
// They are read once, when the device list is made.
static CFPropertyListRef copyPlatformPreference(CFStringRef key) {
	return CFPreferencesCopyValue(key, CFSTR("org.darlinghq.platform"), kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
}

// PreferredGPU: the index of a device in MTLCopyAllDevices() or a part of its name.
static std::string preferredGPU(void) {
	std::string preference;
	CFPropertyListRef value = copyPlatformPreference(CFSTR("PreferredGPU"));
	if (!value) {
		return preference;
	}
	if (CFGetTypeID(value) == CFStringGetTypeID()) {
		preference = [(NSString*)value UTF8String] ?: "";
	} else if (CFGetTypeID(value) == CFNumberGetTypeID()) {
		long long index = -1;
		if (CFNumberGetValue((CFNumberRef)value, kCFNumberLongLongType, &index) && index >= 0) {
			preference = std::to_string(index);
		}
	}
	CFRelease(value);
	return preference;
}

static BOOL copyBoolPreference(CFStringRef key, BOOL* result) {
	CFPropertyListRef value = copyPlatformPreference(key);
	if (!value) {
		return NO;
	}
	BOOL found = NO;
	if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
		*result = CFBooleanGetValue((CFBooleanRef)value);
		found = YES;
	} else if (CFGetTypeID(value) == CFNumberGetTypeID()) {
		long long number = 0;
		if (CFNumberGetValue((CFNumberRef)value, kCFNumberLongLongType, &number)) {
			*result = number != 0;
			found = YES;
		}
	}
	CFRelease(value);
	return found;
}

static void applyPlatformIdentity(MTLDeviceInternal* defaultDevice) {
	CFPropertyListRef name = copyPlatformPreference(CFSTR("GPUName"));
	if (name) {
		if (CFGetTypeID(name) == CFStringGetTypeID() && CFStringGetLength((CFStringRef)name) > 0) {
			[defaultDevice setReportedName: (NSString*)name];
		}
		CFRelease(name);
	}

	CFPropertyListRef memory = copyPlatformPreference(CFSTR("GPUMemoryMB"));
	if (memory) {
		long long megabytes = 0;
		if (CFGetTypeID(memory) == CFNumberGetTypeID() && CFNumberGetValue((CFNumberRef)memory, kCFNumberLongLongType, &megabytes) &&
		    megabytes > 0 && static_cast<unsigned long long>(megabytes) <= UINT64_MAX / (1024 * 1024)) {
			[defaultDevice setReportedWorkingSetSize: static_cast<uint64_t>(megabytes) * 1024 * 1024];
		}
		CFRelease(memory);
	}

	BOOL unifiedMemory = YES;
	if (copyBoolPreference(CFSTR("GPUHasUnifiedMemory"), &unifiedMemory)) {
		for (MTLDeviceInternal* device in devices) {
			[device setReportedUnifiedMemory: unifiedMemory];
		}
	}
}

static void ensureDevices(void) {
	dispatch_once(&devicesInitToken, ^{
		ensureMetalInitialized();
		devices = [NSMutableArray new];

		// Indium lists the default device first. Wrapping a device is cheap: Indium creates its
		// Vulkan device only once something is created on it.
		for (const auto& indiumDevice: Indium::copyAllDevices()) {
			MTLDeviceInternal* device = [[MTLDeviceInternal alloc] initWithDevice: indiumDevice];
			[devices addObject: device];
			[device release];
		}

		if (devices.count == 0) {
			return;
		}

		auto chosen = Indium::createSystemDefaultDevice(preferredGPU());
		for (MTLDeviceInternal* device in devices) {
			if (device.device == chosen) {
				systemDefaultDevice = [device retain];
				break;
			}
		}
		if (!systemDefaultDevice) {
			systemDefaultDevice = [devices[0] retain];
		}

		applyPlatformIdentity(systemDefaultDevice);
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

static NSError* MSLLibraryError(NSString* reason, MTLLibraryError code) {
	return [NSError errorWithDomain: MTLLibraryErrorDomain
	                           code: code
	                       userInfo: @{
		NSLocalizedDescriptionKey: reason,
	}];
}

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
	NSString* _name;
	BOOL _lowPower;
	uint64_t _reportedWorkingSetSize;
	BOOL _unifiedMemory;
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
		_name = [[NSString alloc] initWithUTF8String: MTLDeviceInfo::metalNameFromVulkanName(_device->name().c_str()).c_str()];

		// On a Mac with automatic graphics switching, the integrated GPU is the low-power one.
		if (_device->deviceType() == Indium::DeviceType::IntegratedGPU) {
			for (const auto& other: Indium::copyAllDevices()) {
				if (other->deviceType() == Indium::DeviceType::DiscreteGPU) {
					_lowPower = YES;
					break;
				}
			}
		}

		// Implementation limit: Indium does not complete the Managed (didModifyRange:,
		// synchronizeResource:) and Private upload paths that applications take on a GPU without
		// unified memory, so every device reports unified memory until they work, unless the
		// GPUHasUnifiedMemory setting says otherwise.
		_unifiedMemory = YES;

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
	[_name release];

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

- (NSString*)name
{
	return _name;
}

- (uint64_t)registryID
{
	return MTLDeviceInfo::registryIDFromUUID(_device->deviceUUID());
}

- (BOOL)isLowPower
{
	return _lowPower;
}

- (BOOL)isHeadless
{
	// whether a GPU drives no display is not known through Vulkan
	return NO;
}

- (BOOL)isRemovable
{
	// external GPUs are not told apart from internal ones through Vulkan
	return NO;
}

- (BOOL)hasUnifiedMemory
{
	return _unifiedMemory;
}

- (uint64_t)recommendedMaxWorkingSetSize
{
	return _reportedWorkingSetSize != 0 ? _reportedWorkingSetSize : _device->recommendedMaxWorkingSetSize();
}

- (void)setReportedName: (NSString*)name
{
	NSString* copy = [name copy];
	[_name release];
	_name = copy;
}

- (void)setReportedWorkingSetSize: (uint64_t)size
{
	_reportedWorkingSetSize = size;
}

- (void)setReportedUnifiedMemory: (BOOL)unifiedMemory
{
	_unifiedMemory = unifiedMemory;
}

- (NSUInteger)maxBufferLength
{
	uint64_t length = _device->maxBufferLength();
	return length > NSUIntegerMax ? NSUIntegerMax : static_cast<NSUInteger>(length);
}

- (BOOL)isDepth24Stencil8PixelFormatSupported
{
	return _device->supportsDepth24Stencil8PixelFormat();
}

- (MTLReadWriteTextureTier)readWriteTextureSupport
{
	// Indium binds read-write textures as Vulkan storage images, which every Vulkan device supports
	return MTLReadWriteTextureTier2;
}

- (BOOL)supportsFamily: (MTLGPUFamily)gpuFamily
{
	return MTLDeviceInfo::supportsFamily(gpuFamily);
}

- (BOOL)supportsFeatureSet: (MTLFeatureSet)featureSet
{
	return MTLDeviceInfo::supportsFeatureSet(featureSet);
}

- (BOOL)supportsShaderBarycentricCoordinates
{
	// See the note in MTLDevice.h: Vulkan has no barycentric decoration to lower
	// onto, so this says what the backend implements.
	return NO;
}

- (MTLArgumentBuffersTier)argumentBuffersSupport
{
	return MTLArgumentBuffersTier1;
}

- (BOOL)supportsTextureSampleCount: (NSUInteger)sampleCount
{
	return sampleCount <= UINT32_MAX && _device->supportsTextureSampleCount(static_cast<uint32_t>(sampleCount));
}

- (id<MTLCommandQueue>)newCommandQueueWithMaxCommandBufferCount: (NSUInteger)maxCommandBufferCount
{
	// Indium does not limit the number of uncompleted command buffers on a queue
	return [self newCommandQueue];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithDescriptor: (MTLComputePipelineDescriptor*)descriptor
                                                             options: (MTLPipelineOption)options
                                                          reflection: (MTLAutoreleasedComputePipelineReflection*)reflection
                                                               error: (NSError**)error
{
	if (error) {
		*error = nil;
	}
	if (reflection) {
		*reflection = nil;
	}
	auto pso = MTLCallIndium(error, MTLLibraryErrorInternal, [&]() {
		return _device->newComputePipelineState(descriptor.asIndiumDescriptor, static_cast<Indium::PipelineOption>(options), nullptr);
	});
	if (!pso) {
		if (error && !*error) {
			*error = MTLErrorWithCode(MTLLibraryErrorInternal, @"The pipeline could not be created");
		}
		return nil;
	}
	if (reflection) {
		*reflection = [[[MTLComputePipelineReflection alloc] initWithFunction: ((MTLFunctionInternal*)descriptor.computeFunction).function options: options] autorelease];
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
	if (error) {
		*error = nil;
	}
	if (reflection) {
		*reflection = nil;
	}
	auto pso = MTLCallIndium(error, MTLLibraryErrorInternal, [&]() {
		return _device->newComputePipelineState(((MTLFunctionInternal*)computeFunction).function, static_cast<Indium::PipelineOption>(options), nullptr);
	});
	if (!pso) {
		if (error && !*error) {
			*error = MTLErrorWithCode(MTLLibraryErrorInternal, @"The pipeline could not be created");
		}
		return nil;
	}
	if (reflection) {
		*reflection = [[[MTLComputePipelineReflection alloc] initWithFunction: ((MTLFunctionInternal*)computeFunction).function options: options] autorelease];
	}
	return [[MTLComputePipelineStateInternal alloc] initWithState: pso device: self label: nil];
}

- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                                             error: (NSError**)error
{
	return [self newRenderPipelineStateWithDescriptor: descriptor options: MTLPipelineOptionNone reflection: nil error: error];
}

- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                                           options: (MTLPipelineOption)options
                                                        reflection: (MTLAutoreleasedRenderPipelineReflection*)reflection
                                                             error: (NSError**)error
{
	if (reflection) {
		*reflection = nil;
	}
	if (error) {
		*error = nil;
	}
	auto pso = MTLCallIndium(error, MTLLibraryErrorInternal, [&]() {
		return _device->newRenderPipelineState([descriptor asIndiumDescriptor]);
	});
	if (!pso) {
		if (error && !*error) {
			*error = MTLErrorWithCode(MTLLibraryErrorInternal, @"The pipeline could not be created");
		}
		return nil;
	}
	if (reflection) {
		*reflection = [[[MTLRenderPipelineReflection alloc] initWithVertexFunction: ((MTLFunctionInternal*)descriptor.vertexFunction).function
		                                                         fragmentFunction: ((MTLFunctionInternal*)descriptor.fragmentFunction).function
		                                                                  options: options] autorelease];
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

// The size of one pixel of the formats an IOSurface plane can back here, or 0. These are the
// uncompressed color formats whose memory layout is the same in a linear Vulkan image.
static size_t iosurfacePixelSize(MTLPixelFormat format)
{
	switch (format) {
	case MTLPixelFormatR8Unorm:
		return 1;
	case MTLPixelFormatRG8Unorm:
		return 2;
	case MTLPixelFormatRGBA8Unorm:
	case MTLPixelFormatRGBA8Unorm_sRGB:
	case MTLPixelFormatBGRA8Unorm:
	case MTLPixelFormatBGRA8Unorm_sRGB:
		return 4;
	default:
		return 0;
	}
}

// CPU writes made under an IOSurface lock are what the GPU reads, and GPU writes are what the
// CPU sees under the next lock once the command buffer that made them has completed. Where
// IOSurface exports the plane as a DMA-BUF and the device imports it, the texture uses the
// plane's memory itself. Otherwise (the host or its driver cannot share memory that way, or it
// was turned off) the texture holds a copy, which MTLIOSurfaceCopy keeps in step with the
// plane: uploaded before GPU use after CPU writes, and written back on lock.
- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor
                                 iosurface: (IOSurfaceRef)iosurface
                                     plane: (NSUInteger)plane
{
	if (descriptor == nil || iosurface == NULL) {
		return nil;
	}
	if (descriptor.textureType != MTLTextureType2D || descriptor.mipmapLevelCount != 1 ||
	    descriptor.sampleCount != 1 || descriptor.arrayLength != 1 || descriptor.depth != 1) {
		return nil;
	}

	// A surface without planes has its single plane at index 0.
	size_t planeCount = IOSurfaceGetPlaneCount(iosurface);
	if (plane >= (planeCount == 0 ? 1 : planeCount)) {
		return nil;
	}

	size_t pixelSize = iosurfacePixelSize(descriptor.pixelFormat);
	if (pixelSize == 0 || IOSurfaceGetBytesPerElementOfPlane(iosurface, plane) != pixelSize ||
	    descriptor.width == 0 || descriptor.height == 0 ||
	    descriptor.width > IOSurfaceGetWidthOfPlane(iosurface, plane) ||
	    descriptor.height > IOSurfaceGetHeightOfPlane(iosurface, plane)) {
		return nil;
	}

	std::shared_ptr<Indium::Texture> texture;
	_IOSurfaceDMABuf buffer {};
	buffer.version = _IOSURFACE_DMABUF_VERSION;
	if (_device->supportsDMABufImport() && _IOSurfaceGetDMABuf(iosurface, plane, &buffer)) {
		texture = _device->newTextureWithDMABuf([descriptor asIndiumDescriptor], buffer.fd, buffer.offset, buffer.bytesPerRow);
	}

	MTLIOSurfaceCopy* copy = nullptr;
	if (!texture) {
		// The copy is read and written by the CPU, so it lives in host-visible memory whatever
		// storage mode the descriptor asks for.
		auto indiumDescriptor = [descriptor asIndiumDescriptor];
		constexpr size_t storageModeBits = 0xf << 4;
		indiumDescriptor.resourceOptions = static_cast<Indium::ResourceOptions>(
			static_cast<size_t>(indiumDescriptor.resourceOptions) & ~storageModeBits);
		try {
			texture = _device->newTexture(indiumDescriptor);
		} catch (const std::exception&) {
			return nil;
		}
		copy = texture ? MTLIOSurfaceCopyCreate(texture, iosurface, plane) : nullptr;
		if (copy == nullptr) {
			return nil;
		}
	}
	return [[MTLTextureInternal alloc] initWithTexture: texture
	                                            device: self
	                                   resourceOptions: descriptor.resourceOptions
	                                         iosurface: iosurface
	                                             plane: plane
	                                              copy: copy];
}

- (id<MTLSamplerState>)newSamplerStateWithDescriptor: (MTLSamplerDescriptor*)descriptor
{
	auto state = _device->newSamplerState([descriptor asIndiumDescriptor]);
	if (!state) {
		return nil;
	}
	MTLSamplerStateInternal* sampler = [[MTLSamplerStateInternal alloc] initWithState: state device: self];
	sampler.label = descriptor.label;
	return sampler;
}

- (id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor: (MTLDepthStencilDescriptor*)descriptor
{
	auto state = _device->newDepthStencilState([descriptor asIndiumDescriptor]);
	if (!state) {
		return nil;
	}
	return [[MTLDepthStencilStateInternal alloc] initWithState: state device: self];
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
			*error = MTLErrorWithCode(MTLLibraryErrorFileNotFound, @"The bundle has no default.metallib");
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
	return [self newLibraryWithBytes: data.bytes length: data.length error: error];
}

- (id<MTLLibrary>)newLibraryWithData: (dispatch_data_t)data
                               error: (NSError**)error
{
	if (!data) {
		MTLSetError(error, MTLLibraryErrorInternal, @"No library data");
		return nil;
	}
	// a dispatch_data_t may be made of several regions; map it to one contiguous buffer
	const void* bytes = nullptr;
	size_t length = 0;
	dispatch_data_t contiguous = dispatch_data_create_map(data, &bytes, &length);
	id<MTLLibrary> library = [self newLibraryWithBytes: bytes length: length error: error];
	dispatch_release(contiguous);
	return library;
}

- (id<MTLLibrary>)newLibraryWithBytes: (const void*)bytes
                               length: (size_t)length
                                error: (NSError**)error
{
	if (error) {
		*error = nil;
	}
	auto lib = MTLCallIndium(error, MTLLibraryErrorCompileFailure, [&]() {
		return _device->newLibrary(bytes, length);
	});
	if (!lib) {
		if (error && !*error) {
			*error = MTLErrorWithCode(MTLLibraryErrorCompileFailure, @"The library could not be translated");
		}
		return nil;
	}
	return [[MTLLibraryInternal alloc] initWithLibrary: lib device: self];
}

- (id<MTLLibrary>)newLibraryWithSource: (NSString*)source
                               options: (MTLCompileOptions*)options
                                 error: (NSError**)error
{
	if (source == nil) {
		if (error) {
			*error = MSLLibraryError(@"there is no source to compile",
				MTLLibraryErrorCompileFailure);
		}
		return nil;
	}

	// mslc takes the source as bytes rather than as a string, and takes the length
	// explicitly, so the encoding has to be decided here rather than inferred. A
	// string that is not representable in UTF-8 is refused instead of being
	// silently truncated at the first byte that is not part of a character, which
	// would compile to a module from a source nobody wrote.
	NSData* utf8 = [source dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: NO];
	if (utf8 == nil) {
		if (error) {
			*error = MSLLibraryError(@"the source is not representable in UTF-8",
				MTLLibraryErrorCompileFailure);
		}
		return nil;
	}

	MslcOptions mslcOptions;
	mslc_default_options(&mslcOptions);

	// `options` is accepted and not read, because this framework's
	// MTLCompileOptions declares no properties: an options object here carries no
	// state, so it cannot change the output and nothing is being dropped. That is
	// not true of Apple's class, which has fastMathEnabled, languageVersion and
	// libraryPath. When those are added here, the ones mslc cannot honour have to
	// be refused rather than ignored, in this method and nowhere else: an app that
	// asks for a language version it does not get must get an error, not a library
	// compiled at a different version than it asked for.

	uint8_t* spirv = NULL;
	size_t spirvSize = 0;
	char* reflection = NULL;
	char* diagnostic = NULL;

	int translated = mslc_translate(
		static_cast<const char*>([utf8 bytes]), [utf8 length], &mslcOptions,
		&spirv, &spirvSize, &reflection, &diagnostic);

	if (translated != 0) {
		NSString* reason = (diagnostic != NULL)
			? [NSString stringWithUTF8String: diagnostic]
			: @"mslc reported a failure with no diagnostic";

		if (error) {
			*error = MSLLibraryError(
				[NSString stringWithFormat: @"mslc could not compile the source: %@", reason],
				MTLLibraryErrorCompileFailure);
		}

		mslc_free(spirv);
		mslc_free(reflection);
		mslc_free(diagnostic);
		return nil;
	}

	Indium::LibraryReflection libraryReflection;
	NSString* reflectionError = nil;

	if (!MTLReadMSLReflection(reflection, (reflection != NULL) ? strlen(reflection) : 0,
		libraryReflection, reflectionError))
	{
		if (error) {
			*error = MSLLibraryError(
				[NSString stringWithFormat:
					@"mslc compiled the source but its reflection cannot be used: %@",
					reflectionError],
				MTLLibraryErrorUnsupported);
		}

		mslc_free(spirv);
		mslc_free(reflection);
		mslc_free(diagnostic);
		return nil;
	}

	std::string indiumError;
	auto library = _device->newLibrary(spirv, spirvSize, libraryReflection, &indiumError);

	// indium borrows the module and the reflection for the call and nothing
	// longer, so both go back before the library is handed out rather than after
	// it is used.
	mslc_free(spirv);
	mslc_free(reflection);
	mslc_free(diagnostic);

	if (!library) {
		if (error) {
			*error = MSLLibraryError(
				[NSString stringWithFormat: @"indium refused the module mslc produced: %s",
					indiumError.empty() ? "no reason given" : indiumError.c_str()],
				MTLLibraryErrorCompileFailure);
		}
		return nil;
	}

	return [[MTLLibraryInternal alloc] initWithLibrary: library device: self];
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
