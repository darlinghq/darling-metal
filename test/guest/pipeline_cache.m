// Copyright (C) 2026 Lubos Dolezel
// Pipeline state creation:
//  - the asynchronous variants (-newComputePipelineStateWithFunction:completionHandler: and the others)
//    call their handler exactly once, on a thread other than the caller's, with a usable state, and with an
//    error rather than a state when the pipeline cannot be made;
//  - with --errors (Darling only): a pipeline that cannot be made gives the handler an error and no state;
//  - with --restart-timing (Darling only): the same render pipelines are made in two runs of this program
//    sharing one cache directory, and the second run is faster because the driver's pipeline cache was
//    saved by the first. The shader caches of the GPU drivers are turned off for the runs so that only
//    Indium's own cache is measured.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include "pipeline_cache_compute_metallib.h"
#include "pipeline_cache_render_metallib.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLLibrary> libraryFrom(id<MTLDevice> device, const unsigned char* bytes, unsigned int length) {
	dispatch_data_t data = dispatch_data_create(bytes, length, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
	NSError* error = nil;
	id<MTLLibrary> library = [device newLibraryWithData: data error: &error];
	if (library == nil) {
		printf("newLibraryWithData failed: %s\n", error.localizedDescription.UTF8String);
	}
	return library;
}

// One call of a handler: counts the calls, remembers the thread and the arguments
@interface Probe : NSObject {
@public
	pthread_t caller;
	int calls;
	BOOL onCallerThread;
	id state;
	id reflection;
	NSError* error;
	dispatch_semaphore_t done;
}
@end

@implementation Probe
- (instancetype)init {
	self = [super init];
	caller = pthread_self();
	done = dispatch_semaphore_create(0);
	return self;
}
- (void)record: (id)aState reflection: (id)aReflection error: (NSError*)anError {
	@synchronized (self) {
		calls++;
		onCallerThread = pthread_equal(pthread_self(), caller) != 0;
		state = [aState retain];
		reflection = [aReflection retain];
		error = [anError retain];
	}
	dispatch_semaphore_signal(done);
}
@end

// Waits for the handler, then a little longer to see that it is not called again
static BOOL waitForProbe(Probe* probe) {
	if (dispatch_semaphore_wait(probe->done, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) != 0) {
		return NO;
	}
	usleep(200 * 1000);
	return YES;
}

static MTLRenderPipelineDescriptor* renderDescriptor(id<MTLLibrary> library, MTLPixelFormat color, MTLPixelFormat depth) {
	MTLRenderPipelineDescriptor* descriptor = [[[MTLRenderPipelineDescriptor alloc] init] autorelease];
	descriptor.vertexFunction = [[library newFunctionWithName: @"vertex_project"] autorelease];
	descriptor.fragmentFunction = [[library newFunctionWithName: @"fragment_light"] autorelease];
	descriptor.colorAttachments[0].pixelFormat = color;
	descriptor.depthAttachmentPixelFormat = depth;
	return descriptor;
}

// Runs a compute pipeline over 8 floats: out[i] = in[i] + in[i]
static BOOL computeWorks(id<MTLDevice> device, id<MTLComputePipelineState> pipeline) {
	id<MTLCommandQueue> queue = [[device newCommandQueue] autorelease];
	id<MTLBuffer> a = [[device newBufferWithLength: 8 * sizeof(float) options: MTLResourceStorageModeShared] autorelease];
	id<MTLBuffer> out = [[device newBufferWithLength: 8 * sizeof(float) options: MTLResourceStorageModeShared] autorelease];
	for (int i = 0; i < 8; ++i) {
		((float*)a.contents)[i] = i + 1;
	}
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
	[encoder setComputePipelineState: pipeline];
	[encoder setBuffer: a offset: 0 atIndex: 0];
	[encoder setBuffer: a offset: 0 atIndex: 1];
	[encoder setBuffer: out offset: 0 atIndex: 2];
	[encoder dispatchThreads: MTLSizeMake(8, 1, 1) threadsPerThreadgroup: MTLSizeMake(8, 1, 1)];
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	for (int i = 0; i < 8; ++i) {
		if (((float*)out.contents)[i] != 2 * (i + 1)) {
			return NO;
		}
	}
	return YES;
}

static void testAsyncCreation(id<MTLDevice> device) {
	id<MTLLibrary> computeLibrary = libraryFrom(device, pipeline_cache_compute_metallib, pipeline_cache_compute_metallib_len);
	id<MTLLibrary> renderLibrary = libraryFrom(device, pipeline_cache_render_metallib, pipeline_cache_render_metallib_len);
	CHECK(computeLibrary != nil && renderLibrary != nil);
	if (!computeLibrary || !renderLibrary) {
		return;
	}
	id<MTLFunction> kernel = [computeLibrary newFunctionWithName: @"add_arrays"];

	// compute, from a function
	{
		Probe* probe = [[Probe alloc] init];
		[device newComputePipelineStateWithFunction: kernel completionHandler: ^(id<MTLComputePipelineState> state, NSError* error) {
			[probe record: state reflection: nil error: error];
		}];
		CHECK(waitForProbe(probe));
		CHECK(probe->calls == 1);
		CHECK(!probe->onCallerThread);
		CHECK(probe->state != nil && probe->error == nil);
		CHECK(computeWorks(device, probe->state));
	}

	// compute, from a function, with options: the reflection comes with it
	{
		Probe* probe = [[Probe alloc] init];
		[device newComputePipelineStateWithFunction: kernel options: MTLPipelineOptionArgumentInfo completionHandler: ^(id<MTLComputePipelineState> state, MTLComputePipelineReflection* reflection, NSError* error) {
			[probe record: state reflection: reflection error: error];
		}];
		CHECK(waitForProbe(probe));
		CHECK(probe->calls == 1);
		CHECK(!probe->onCallerThread);
		CHECK(probe->state != nil && probe->error == nil);
		CHECK(probe->reflection != nil);
		CHECK(computeWorks(device, probe->state));
	}

	// compute, from a descriptor; the descriptor may be changed once the call has returned (what the handler gets was copied)
	{
		MTLComputePipelineDescriptor* descriptor = [[MTLComputePipelineDescriptor alloc] init];
		descriptor.computeFunction = kernel;
		Probe* probe = [[Probe alloc] init];
		[device newComputePipelineStateWithDescriptor: descriptor options: MTLPipelineOptionNone completionHandler: ^(id<MTLComputePipelineState> state, MTLComputePipelineReflection* reflection, NSError* error) {
			[probe record: state reflection: reflection error: error];
		}];
		descriptor.label = @"changed after the call";
		CHECK(waitForProbe(probe));
		CHECK(probe->calls == 1);
		CHECK(!probe->onCallerThread);
		CHECK(probe->state != nil && probe->error == nil);
		CHECK(computeWorks(device, probe->state));
		[descriptor release];
	}

	// render
	{
		MTLRenderPipelineDescriptor* descriptor = renderDescriptor(renderLibrary, MTLPixelFormatRGBA8Unorm, MTLPixelFormatDepth32Float);
		Probe* probe = [[Probe alloc] init];
		[device newRenderPipelineStateWithDescriptor: descriptor completionHandler: ^(id<MTLRenderPipelineState> state, NSError* error) {
			[probe record: state reflection: nil error: error];
		}];
		descriptor.label = @"changed after the call";
		CHECK(waitForProbe(probe));
		CHECK(probe->calls == 1);
		CHECK(!probe->onCallerThread);
		CHECK(probe->state != nil && probe->error == nil);
	}

	// render, with options
	{
		MTLRenderPipelineDescriptor* descriptor = renderDescriptor(renderLibrary, MTLPixelFormatBGRA8Unorm, MTLPixelFormatInvalid);
		Probe* probe = [[Probe alloc] init];
		[device newRenderPipelineStateWithDescriptor: descriptor options: MTLPipelineOptionArgumentInfo completionHandler: ^(id<MTLRenderPipelineState> state, MTLRenderPipelineReflection* reflection, NSError* error) {
			[probe record: state reflection: reflection error: error];
		}];
		CHECK(waitForProbe(probe));
		CHECK(probe->calls == 1);
		CHECK(!probe->onCallerThread);
		CHECK(probe->state != nil && probe->error == nil);
		CHECK(probe->reflection != nil);
	}

}

// A pipeline that cannot be made: the handler gets an error and no state, once. A render pipeline needs a vertex
// function. macOS stops on its descriptor validation for this instead of reporting an error, so it only runs with
// --errors.
static void testAsyncError(id<MTLDevice> device) {
	{
		MTLRenderPipelineDescriptor* descriptor = [[[MTLRenderPipelineDescriptor alloc] init] autorelease];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
		Probe* probe = [[Probe alloc] init];
		[device newRenderPipelineStateWithDescriptor: descriptor completionHandler: ^(id<MTLRenderPipelineState> state, NSError* error) {
			[probe record: state reflection: nil error: error];
		}];
		CHECK(waitForProbe(probe));
		CHECK(probe->calls == 1);
		CHECK(probe->state == nil && probe->error != nil);
	}
}

// ---- timing between two runs (Darling) ------------------------------------------------------------------

static double nowMilliseconds(void) {
	struct timespec spec;
	clock_gettime(CLOCK_MONOTONIC, &spec);
	return spec.tv_sec * 1000.0 + spec.tv_nsec / 1e6;
}

// Makes render pipelines for several attachment formats and uses each in a pass (the Vulkan pipeline is made
// when the pipeline state is first set on an encoder), and prints the time it took.
static int timingChild(id<MTLDevice> device) {
	id<MTLCommandQueue> queue = [[device newCommandQueue] autorelease];
	MTLPixelFormat colors[] = { MTLPixelFormatRGBA8Unorm, MTLPixelFormatBGRA8Unorm, MTLPixelFormatRGBA16Float, MTLPixelFormatRGBA32Float, MTLPixelFormatR8Unorm };
	double start = nowMilliseconds();
	id<MTLLibrary> library = libraryFrom(device, pipeline_cache_render_metallib, pipeline_cache_render_metallib_len);
	if (!library) {
		return 1;
	}
	for (int withDepth = 0; withDepth < 2; ++withDepth) {
		for (size_t i = 0; i < sizeof(colors) / sizeof(colors[0]); ++i) {
			MTLPixelFormat depthFormat = withDepth ? MTLPixelFormatDepth32Float : MTLPixelFormatInvalid;
			NSError* error = nil;
			id<MTLRenderPipelineState> state = [device newRenderPipelineStateWithDescriptor: renderDescriptor(library, colors[i], depthFormat) error: &error];
			if (!state) {
				printf("pipeline failed: %s\n", error.localizedDescription.UTF8String);
				return 1;
			}
			MTLTextureDescriptor* colorDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: colors[i] width: 16 height: 16 mipmapped: NO];
			colorDescriptor.usage = MTLTextureUsageRenderTarget;
			colorDescriptor.storageMode = MTLStorageModePrivate;
			MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
			pass.colorAttachments[0].texture = [[device newTextureWithDescriptor: colorDescriptor] autorelease];
			pass.colorAttachments[0].loadAction = MTLLoadActionClear;
			pass.colorAttachments[0].storeAction = MTLStoreActionStore;
			if (withDepth) {
				MTLTextureDescriptor* depthDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatDepth32Float width: 16 height: 16 mipmapped: NO];
				depthDescriptor.usage = MTLTextureUsageRenderTarget;
				depthDescriptor.storageMode = MTLStorageModePrivate;
				pass.depthAttachment.texture = [[device newTextureWithDescriptor: depthDescriptor] autorelease];
				pass.depthAttachment.loadAction = MTLLoadActionClear;
				pass.depthAttachment.storeAction = MTLStoreActionStore;
			}
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLRenderCommandEncoder> encoder = [commands renderCommandEncoderWithDescriptor: pass];
			[encoder setRenderPipelineState: state];
			[encoder endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			[state release];
		}
	}
	printf("TIME %.3f\n", nowMilliseconds() - start);
	return 0;
}

// Runs this program with --timing-child and returns the time it reports, or -1
static double runTimingChild(const char* self, const char* cacheDirectory) {
	setenv("INDIUM_PIPELINE_CACHE_DIR", cacheDirectory, 1);
	setenv("__GL_SHADER_DISK_CACHE", "0", 1);
	setenv("MESA_SHADER_CACHE_DISABLE", "true", 1);
	FILE* pipe = popen([[NSString stringWithFormat: @"'%s' --timing-child 2>&1", self] UTF8String], "r");
	if (!pipe) {
		return -1;
	}
	double result = -1;
	char line[512];
	while (fgets(line, sizeof(line), pipe)) {
		if (strncmp(line, "TIME ", 5) == 0) {
			result = atof(line + 5);
		} else {
			printf("  child: %s", line);
		}
	}
	pclose(pipe);
	return result;
}

static void testRestartTiming(const char* self) {
	char directory[] = "/tmp/pipeline-cache-XXXXXX";
	if (!mkdtemp(directory)) {
		CHECK(0 && "mkdtemp");
		return;
	}
	double first = runTimingChild(self, directory);
	double second = runTimingChild(self, directory);
	double third = runTimingChild(self, directory);
	printf("render pipelines for 10 formats: first run %.1f ms, second %.1f ms, third %.1f ms\n", first, second, third);
	CHECK(first > 0 && second > 0 && third > 0);
	// generous: the saved cache must make a run clearly faster than the one that had to compile everything
	CHECK(second < first * 0.8);
	CHECK(third < first * 0.8);
	[[NSFileManager defaultManager] removeItemAtPath: [NSString stringWithUTF8String: directory] error: nil];
}

int main(int argc, char** argv) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		BOOL errors = NO, restartTiming = NO;
		for (int i = 1; i < argc; ++i) {
			if (strcmp(argv[i], "--timing-child") == 0) {
				return timingChild(device);
			}
			errors = errors || strcmp(argv[i], "--errors") == 0;
			restartTiming = restartTiming || strcmp(argv[i], "--restart-timing") == 0;
		}

		testAsyncCreation(device);
		if (errors) {
			testAsyncError(device);
		}
		if (restartTiming) {
			testRestartTiming(argv[0]);
		}

		if (failures) {
			printf("%d failure(s)\n", failures);
			return 1;
		}
		printf("ALL PASSED\n");
		return 0;
	}
}
