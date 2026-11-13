// Copyright (C) 2026 Lubos Dolezel
// MTLFunction.vertexAttributes and stageInputAttributes: a vertex function lists its [[stage_in]]
// attributes (name, index, data type) in declaration order and nothing else, other functions list
// none, and the attributes are not reported as pipeline arguments.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "vertex_attributes_metallib.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}

		NSError* error = nil;
		dispatch_data_t data = dispatch_data_create(vertex_attributes_metallib, sizeof(vertex_attributes_metallib), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
		id<MTLLibrary> library = [device newLibraryWithData: data error: &error];
		CHECK(library != nil);
		if (library == nil) {
			printf("library: %s\n", error.description.UTF8String);
			return 1;
		}

		id<MTLFunction> vertex = [library newFunctionWithName: @"vertex_with_inputs"];
		CHECK(vertex != nil);
		NSArray<MTLVertexAttribute*>* attributes = vertex.vertexAttributes;
		CHECK(attributes.count == 3);
		if (attributes.count == 3) {
			CHECK([attributes[0].name isEqualToString: @"position"]);
			CHECK(attributes[0].attributeIndex == 0);
			CHECK(attributes[0].attributeType == MTLDataTypeFloat4);
			CHECK([attributes[1].name isEqualToString: @"ids"]);
			CHECK(attributes[1].attributeIndex == 3);
			CHECK(attributes[1].attributeType == MTLDataTypeUInt2);
			CHECK([attributes[2].name isEqualToString: @"weight"]);
			CHECK(attributes[2].attributeIndex == 5);
			CHECK(attributes[2].attributeType == MTLDataTypeFloat);
			for (MTLVertexAttribute* attribute in attributes) {
				CHECK(attribute.isActive);
				CHECK(!attribute.isPatchData);
				CHECK(!attribute.isPatchControlPointData);
			}
		}
		NSArray<MTLAttribute*>* stageInputs = vertex.stageInputAttributes;
		CHECK(stageInputs.count == 3);
		if (stageInputs.count == 3) {
			CHECK([stageInputs[1].name isEqualToString: @"ids"]);
			CHECK(stageInputs[1].attributeIndex == 3);
			CHECK(stageInputs[1].attributeType == MTLDataTypeUInt2);
		}

		id<MTLFunction> bare = [library newFunctionWithName: @"vertex_without_inputs"];
		CHECK(bare != nil);
		CHECK(bare.vertexAttributes != nil && bare.vertexAttributes.count == 0);
		CHECK(bare.stageInputAttributes != nil && bare.stageInputAttributes.count == 0);

		for (NSString* name in @[@"fragment_main", @"kernel_main"]) {
			id<MTLFunction> other = [library newFunctionWithName: name];
			CHECK(other != nil);
			CHECK(other.vertexAttributes == nil);
			CHECK(other.stageInputAttributes == nil);
		}

		// the kernel's reflection lists its buffer only
		id<MTLFunction> kernel = [library newFunctionWithName: @"kernel_main"];
		MTLComputePipelineReflection* reflection = nil;
		id<MTLComputePipelineState> state = [device newComputePipelineStateWithFunction: kernel options: MTLPipelineOptionArgumentInfo reflection: &reflection error: &error];
		CHECK(state != nil);
		CHECK(reflection.arguments.count == 1);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
