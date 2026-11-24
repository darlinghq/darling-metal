// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// MTLFunctionDescriptor and -[MTLLibrary newFunctionWithDescriptor:error:] (and its completion handler variant):
// the descriptor's defaults and copies, a function made from a descriptor, its specialized name and options, values
// for constants the function does not have, and the error for a function the library does not have.
// The expectations follow Apple's documentation and were checked on macOS 27 (Apple M1).
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

// runs `function` on 4 threads over a buffer of 4 zeroes and returns the first value
static uint32_t runOnce(id<MTLDevice> device, id<MTLFunction> function) {
	NSError* error = nil;
	id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction: function error: &error];
	if (pipeline == nil) {
		printf("pipeline: %s\n", error.localizedDescription.UTF8String);
		return 0;
	}
	id<MTLBuffer> buffer = [device newBufferWithLength: 4 * sizeof(uint32_t) options: MTLResourceStorageModeShared];
	memset(buffer.contents, 0, buffer.length);
	id<MTLCommandQueue> queue = [device newCommandQueue];
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
	[encoder setComputePipelineState: pipeline];
	[encoder setBuffer: buffer offset: 0 atIndex: 0];
	[encoder dispatchThreads: MTLSizeMake(4, 1, 1) threadsPerThreadgroup: MTLSizeMake(4, 1, 1)];
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	uint32_t value = ((uint32_t*)buffer.contents)[0];
	[buffer release];
	[queue release];
	[pipeline release];
	return value;
}

int main(void) {
	@autoreleasepool {
		// --- the descriptor
		MTLFunctionDescriptor* descriptor = [MTLFunctionDescriptor functionDescriptor];
		CHECK(descriptor != nil);
		CHECK(descriptor.name == nil && descriptor.specializedName == nil);
		CHECK(descriptor.constantValues == nil && descriptor.binaryArchives == nil);
		CHECK(descriptor.options == MTLFunctionOptionNone);
		MTLFunctionDescriptor* fresh = [[MTLFunctionDescriptor alloc] init];
		CHECK(fresh.name == nil && fresh.options == MTLFunctionOptionNone);
		[fresh release];

		NSMutableString* name = [NSMutableString stringWithString: @"seven"];
		descriptor.name = name;
		[name appendString: @"teen"];
		CHECK([descriptor.name isEqualToString: @"seven"]);
		descriptor.specializedName = @"special";
		descriptor.options = MTLFunctionOptionCompileToBinary;
		MTLFunctionConstantValues* values = [[MTLFunctionConstantValues new] autorelease];
		descriptor.constantValues = values;
		CHECK(descriptor.constantValues != nil && descriptor.constantValues != values);

		MTLFunctionDescriptor* copy = [[descriptor copy] autorelease];
		CHECK(copy != descriptor && [copy isKindOfClass: [MTLFunctionDescriptor class]]);
		CHECK([copy.name isEqualToString: @"seven"] && [copy.specializedName isEqualToString: @"special"]);
		CHECK(copy.options == MTLFunctionOptionCompileToBinary && copy.constantValues != nil);
		descriptor.name = @"eight";
		CHECK([copy.name isEqualToString: @"seven"]);

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		NSError* error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:
			@"#include <metal_stdlib>\nusing namespace metal;\n"
			"kernel void seven(device uint* out [[buffer(0)]], uint i [[thread_position_in_grid]]) { out[i] = 7; }\n"
			"kernel void eight(device uint* out [[buffer(0)]], uint i [[thread_position_in_grid]]) { out[i] = 8; }\n"
			options: nil error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("library: %s\n", error.localizedDescription.UTF8String);
			printf("FAILED: %d\n", failures);
			return 1;
		}

		// --- a function from a descriptor with only a name
		descriptor = [MTLFunctionDescriptor functionDescriptor];
		descriptor.name = @"seven";
		id<MTLFunction> function = [library newFunctionWithDescriptor: descriptor error: &error];
		CHECK(function != nil && error == nil);
		CHECK([function.name isEqualToString: @"seven"]);
		CHECK(function.functionType == MTLFunctionTypeKernel);
		CHECK(function.options == MTLFunctionOptionNone);
		CHECK(function.device == device);
		CHECK(runOnce(device, function) == 7);
		[function release];

		// --- a specialized name, options, and values for constants the function does not have
		descriptor.name = @"eight";
		descriptor.specializedName = @"eight_special";
		descriptor.options = MTLFunctionOptionCompileToBinary;
		descriptor.constantValues = values;
		function = [library newFunctionWithDescriptor: descriptor error: &error];
		CHECK(function != nil && error == nil);
		CHECK([function.name isEqualToString: @"eight_special"]);
		CHECK(function.options == MTLFunctionOptionCompileToBinary);
		CHECK(runOnce(device, function) == 8);
		[function release];

		// --- a function the library does not have
		descriptor = [MTLFunctionDescriptor functionDescriptor];
		descriptor.name = @"nine";
		function = [library newFunctionWithDescriptor: descriptor error: &error];
		CHECK(function == nil);
		CHECK(error != nil && [error.domain isEqualToString: MTLLibraryErrorDomain] && error.code == MTLLibraryErrorFunctionNotFound);
		descriptor.constantValues = values;
		error = nil;
		function = [library newFunctionWithDescriptor: descriptor error: &error];
		CHECK(function == nil);
		CHECK(error != nil && [error.domain isEqualToString: MTLLibraryErrorDomain] && error.code == MTLLibraryErrorFunctionNotFound);

		// --- with a completion handler
		dispatch_semaphore_t foundDone = dispatch_semaphore_create(0), missingDone = dispatch_semaphore_create(0);
		__block BOOL found = NO, missing = NO;
		descriptor = [MTLFunctionDescriptor functionDescriptor];
		descriptor.name = @"seven";
		[library newFunctionWithDescriptor: descriptor completionHandler: ^(id<MTLFunction> made, NSError* failure) {
			found = made != nil && failure == nil && [made.name isEqualToString: @"seven"];
			dispatch_semaphore_signal(foundDone);
		}];
		CHECK(dispatch_semaphore_wait(foundDone, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) == 0);
		CHECK(found);
		descriptor.name = @"nine";
		[library newFunctionWithDescriptor: descriptor completionHandler: ^(id<MTLFunction> made, NSError* failure) {
			missing = made == nil && failure.code == MTLLibraryErrorFunctionNotFound;
			dispatch_semaphore_signal(missingDone);
		}];
		CHECK(dispatch_semaphore_wait(missingDone, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) == 0);
		CHECK(missing);
		dispatch_release(foundDone);
		dispatch_release(missingDone);

		[library release];
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
