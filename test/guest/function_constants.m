// Copyright (C) 2026 Lubos Dolezel
// MTLFunctionConstantValues, -newFunctionWithName:constantValues:error: and
// MTLFunction.functionConstantsDictionary: values given for a function's constants decide what its
// pipelines compute. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <dispatch/dispatch.h>
#include "function_constants_metallib.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static BOOL raises(void (^block)(void)) {
	@try {
		block();
	} @catch (NSException* e) {
		return [e.name isEqualToString: NSInvalidArgumentException];
	}
	return NO;
}

// Runs fc_simple (out[i] = mode * factor) over 8 elements and returns out[0], or NAN when it fails.
static float runSimple(id<MTLDevice> device, id<MTLFunction> function) {
	NSError* error = nil;
	id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction: function error: &error];
	if (pipeline == nil) {
		return NAN;
	}
	id<MTLCommandQueue> queue = [device newCommandQueue];
	id<MTLBuffer> out = [device newBufferWithLength: 8 * sizeof(float) options: MTLResourceStorageModeShared];
	memset(out.contents, 0, 8 * sizeof(float));
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
	[encoder setComputePipelineState: pipeline];
	[encoder setBuffer: out offset: 0 atIndex: 0];
	[encoder dispatchThreads: MTLSizeMake(8, 1, 1) threadsPerThreadgroup: MTLSizeMake(8, 1, 1)];
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	const float* data = out.contents;
	for (int i = 1; i < 8; ++i) {
		if (data[i] != data[0]) {
			return NAN;
		}
	}
	return data[0];
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}

		// the value store
		MTLFunctionConstantValues* values = [[MTLFunctionConstantValues alloc] init];
		int mode = 3;
		float factor = 2.5f;
		[values setConstantValue: &mode type: MTLDataTypeInt atIndex: 1];
		[values setConstantValue: &factor type: MTLDataTypeFloat withName: @"factor"];
		CHECK(raises(^{ [values setConstantValue: NULL type: MTLDataTypeInt atIndex: 1]; }));
		CHECK(raises(^{ [values setConstantValue: &mode type: MTLDataTypeInt withName: nil]; }));
		CHECK(raises(^{ [values setConstantValue: &mode type: MTLDataTypeFloat2x2 atIndex: 1]; }));
		int range[2] = { 7, 8 };
		[values setConstantValues: range type: MTLDataTypeInt withRange: NSMakeRange(10, 2)];
		MTLFunctionConstantValues* copy = [values copy];
		CHECK(copy != nil && copy != values);

		NSError* error = nil;
		dispatch_data_t data = dispatch_data_create(function_constants_metallib, sizeof(function_constants_metallib), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
		id<MTLLibrary> library = [device newLibraryWithData: data error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("library: %s\n", error.description.UTF8String);
			return 1;
		}

		// reflection
		id<MTLFunction> plain = [library newFunctionWithName: @"fc_kernel"];
		NSDictionary<NSString*, MTLFunctionConstant*>* constants = plain.functionConstantsDictionary;
		CHECK(constants.count == 4);
		CHECK(constants[@"use_scale"].type == MTLDataTypeBool && constants[@"use_scale"].index == 0);
		CHECK(constants[@"mode"].type == MTLDataTypeInt && constants[@"mode"].index == 1);
		CHECK(constants[@"factor"].type == MTLDataTypeFloat && constants[@"factor"].index == 2);
		CHECK(constants[@"opt"].type == MTLDataTypeUInt && constants[@"opt"].index == 3);
		CHECK([[library newFunctionWithName: @"fc_simple"] functionConstantsDictionary].count == 2);

		// specialization: the same values (shared with a function that does not use all of them)
		id<MTLFunction> simple = [library newFunctionWithName: @"fc_simple" constantValues: values error: &error];
		CHECK(simple != nil);
		CHECK(runSimple(device, simple) == 7.5f);

		int otherMode = -4;
		float otherFactor = 0.5f;
		[values setConstantValue: &otherMode type: MTLDataTypeInt atIndex: 1];
		[values setConstantValue: &otherFactor type: MTLDataTypeFloat atIndex: 2];
		id<MTLFunction> other = [library newFunctionWithName: @"fc_simple" constantValues: values error: &error];
		CHECK(runSimple(device, other) == -2.0f);
		// the first function keeps the values it was made with
		CHECK(runSimple(device, simple) == 7.5f);
		// the copy did not follow the later changes
		id<MTLFunction> fromCopy = [library newFunctionWithName: @"fc_simple" constantValues: copy error: &error];
		CHECK(runSimple(device, fromCopy) == 7.5f);

		// errors
		MTLFunctionConstantValues* wrong = [[MTLFunctionConstantValues alloc] init];
		[wrong setConstantValue: &factor type: MTLDataTypeFloat atIndex: 1];
		error = nil;
		CHECK([library newFunctionWithName: @"fc_simple" constantValues: wrong error: &error] == nil);
		CHECK([error.domain isEqualToString: MTLLibraryErrorDomain] && error.code == MTLLibraryErrorCompileFailure);
		error = nil;
		CHECK([library newFunctionWithName: @"nope" constantValues: values error: &error] == nil);
		CHECK([error.domain isEqualToString: MTLLibraryErrorDomain] && error.code == MTLLibraryErrorFunctionNotFound);

		dispatch_semaphore_t done = dispatch_semaphore_create(0);
		__block id<MTLFunction> handlerFunction = nil;
		[library newFunctionWithName: @"fc_simple" constantValues: values completionHandler: ^(id<MTLFunction> function, NSError* e) {
			handlerFunction = [function retain];
			dispatch_semaphore_signal(done);
		}];
		CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0);
		CHECK(handlerFunction != nil && runSimple(device, handlerFunction) == -2.0f);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
