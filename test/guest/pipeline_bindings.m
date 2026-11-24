// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// Pipeline reflection bindings (bindings, vertexBindings, fragmentBindings) of functions from precompiled
// libraries (sample_offset_metallib.h, air_coverage_3_metallib.h, vertex_attributes_metallib.h): one binding
// per resource argument, in declaration order, of the MTLBufferBinding or MTLTextureBinding kind with the
// declared types; a buffer's struct layout only with MTLPipelineOptionBufferTypeInfo, no bindings without an
// option, and none for stage-in attributes.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "sample_offset_metallib.h"
#include "air_coverage_3_metallib.h"
#include "vertex_attributes_metallib.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static id<MTLDevice> device;

static id<MTLLibrary> libraryFrom(const unsigned char* bytes, size_t length) {
	NSError* error = nil;
	dispatch_data_t data = dispatch_data_create(bytes, length, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
	id<MTLLibrary> library = [device newLibraryWithData: data error: &error];
	dispatch_release(data);
	if (library == nil) {
		printf("library: %s\n", error.localizedDescription.UTF8String);
	}
	return [library autorelease];
}

static MTLComputePipelineReflection* computeReflection(id<MTLLibrary> library, NSString* name, MTLPipelineOption options) {
	id<MTLFunction> function = [library newFunctionWithName: name];
	MTLComputePipelineReflection* reflection = nil;
	NSError* error = nil;
	id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction: function options: options reflection: &reflection error: &error];
	if (pipeline == nil) {
		printf("FAIL %s: %s\n", name.UTF8String, error.localizedDescription.UTF8String);
		failures++;
	}
	[pipeline release];
	[function release];
	CHECK(reflection != nil);
	return reflection;
}

// the bindings, if the reflection has the expected number
static NSArray<id<MTLBinding>>* bindingsOf(MTLComputePipelineReflection* reflection, NSUInteger count) {
	CHECK([reflection respondsToSelector: @selector(bindings)]);
	if (![reflection respondsToSelector: @selector(bindings)]) {
		return nil;
	}
	NSArray<id<MTLBinding>>* bindings = reflection.bindings;
	CHECK(bindings != nil && bindings.count == count);
	return bindings.count == count ? bindings : nil;
}

static MTLRenderPipelineReflection* renderReflection(id<MTLLibrary> library, NSString* vertex, NSString* fragment) {
	MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor alloc] init];
	descriptor.vertexFunction = [[library newFunctionWithName: vertex] autorelease];
	descriptor.fragmentFunction = [[library newFunctionWithName: fragment] autorelease];
	descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
	MTLRenderPipelineReflection* reflection = nil;
	NSError* error = nil;
	id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor: descriptor options: MTLPipelineOptionBindingInfo reflection: &reflection error: &error];
	if (pipeline == nil) {
		printf("FAIL %s: %s\n", fragment.UTF8String, error.localizedDescription.UTF8String);
		failures++;
	}
	[pipeline release];
	[descriptor release];
	CHECK([reflection respondsToSelector: @selector(vertexBindings)] && [reflection respondsToSelector: @selector(fragmentBindings)]);
	return [reflection respondsToSelector: @selector(vertexBindings)] && [reflection respondsToSelector: @selector(fragmentBindings)] ? reflection : nil;
}

static BOOL isBinding(id<MTLBinding> binding, NSString* name, MTLBindingType type, NSUInteger index) {
	return [binding.name isEqualToString: name] && binding.type == type && binding.index == index && binding.isUsed && binding.isArgument;
}

static void checkTexture(id<MTLBinding> binding, MTLTextureType type, MTLDataType dataType, MTLBindingAccess access) {
	CHECK([binding conformsToProtocol: @protocol(MTLTextureBinding)]);
	if (![binding conformsToProtocol: @protocol(MTLTextureBinding)]) {
		return;
	}
	id<MTLTextureBinding> texture = (id<MTLTextureBinding>)binding;
	CHECK(texture.textureType == type);
	CHECK(texture.textureDataType == dataType);
	CHECK(!texture.isDepthTexture);
	CHECK(texture.arrayLength == 1);
	CHECK(texture.access == access);
}

int main(void) {
	@autoreleasepool {
		device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		CHECK(MTLPipelineOptionBindingInfo == MTLPipelineOptionArgumentInfo);

		id<MTLLibrary> offsets = libraryFrom(sample_offset_metallib, sizeof(sample_offset_metallib));
		id<MTLLibrary> texelBuffers = libraryFrom(air_coverage_3_metallib, sizeof(air_coverage_3_metallib));
		id<MTLLibrary> vertexInputs = libraryFrom(vertex_attributes_metallib, sizeof(vertex_attributes_metallib));
		if (offsets == nil || texelBuffers == nil || vertexInputs == nil) {
			return 1;
		}

		// sample_kernel_offset(texture2d<float> src [[texture(0)]], device float4* out [[buffer(0)]],
		//                      constant Offsets& offsets [[buffer(1)]], uint2 gid [[thread_position_in_grid]])
		MTLComputePipelineReflection* reflection = computeReflection(offsets, @"sample_kernel_offset", MTLPipelineOptionBindingInfo | MTLPipelineOptionBufferTypeInfo);
		NSArray<id<MTLBinding>>* bindings = bindingsOf(reflection, 3);
		if (bindings != nil) {
			CHECK(isBinding(bindings[0], @"src", MTLBindingTypeTexture, 0));
			checkTexture(bindings[0], MTLTextureType2D, MTLDataTypeFloat, MTLBindingAccessReadOnly);

			CHECK(isBinding(bindings[1], @"out", MTLBindingTypeBuffer, 0));
			CHECK([bindings[1] conformsToProtocol: @protocol(MTLBufferBinding)]);
			id<MTLBufferBinding> out = (id<MTLBufferBinding>)bindings[1];
			CHECK(out.bufferDataType == MTLDataTypeFloat4);
			CHECK(out.bufferDataSize == 16);
			CHECK(out.bufferAlignment == 16);
			CHECK(out.bufferStructType == nil);
			CHECK(out.bufferPointerType == nil);
			CHECK(out.access == MTLBindingAccessReadWrite);

			CHECK(isBinding(bindings[2], @"offsets", MTLBindingTypeBuffer, 1));
			id<MTLBufferBinding> offsetsBinding = (id<MTLBufferBinding>)bindings[2];
			CHECK(offsetsBinding.bufferDataType == MTLDataTypeStruct);
			NSArray<MTLStructMember*>* members = offsetsBinding.bufferStructType.members;
			CHECK(members.count == 2);
			if (members.count == 2) {
				CHECK([members[0].name isEqualToString: @"offset"] && members[0].offset == 0 && members[0].dataType == MTLDataTypeInt2);
				CHECK([members[1].name isEqualToString: @"radius"] && members[1].offset == 8 && members[1].dataType == MTLDataTypeInt);
			}
		}
		CHECK(reflection.arguments.count == 3);

		// without MTLPipelineOptionBufferTypeInfo the data type stays, the layout goes
		bindings = bindingsOf(computeReflection(offsets, @"sample_kernel_offset", MTLPipelineOptionBindingInfo), 3);
		if (bindings != nil) {
			id<MTLBufferBinding> offsetsBinding = (id<MTLBufferBinding>)bindings[2];
			CHECK(offsetsBinding.bufferDataType == MTLDataTypeStruct);
			CHECK(offsetsBinding.bufferStructType == nil);
		}

		// without an option there is nothing to report
		bindingsOf(computeReflection(offsets, @"sample_kernel_offset", MTLPipelineOptionNone), 0);

		// the access and sample type come from the texture's declaration
		bindings = bindingsOf(computeReflection(texelBuffers, @"tb_write", MTLPipelineOptionBindingInfo), 1);
		if (bindings != nil) {
			checkTexture(bindings[0], MTLTextureTypeTextureBuffer, MTLDataTypeFloat, MTLBindingAccessWriteOnly);
		}
		bindings = bindingsOf(computeReflection(texelBuffers, @"tb_uint", MTLPipelineOptionBindingInfo), 1);
		if (bindings != nil) {
			checkTexture(bindings[0], MTLTextureTypeTextureBuffer, MTLDataTypeUInt, MTLBindingAccessReadWrite);
		}

		// render: sample_buffer_offset(Position in [[stage_in]], texture2d<float> src [[texture(0)]],
		// constant Offsets& offsets [[buffer(0)]])
		MTLRenderPipelineReflection* render = renderReflection(offsets, @"cover", @"sample_buffer_offset");
		if (render != nil) {
			CHECK(render.vertexBindings != nil && render.vertexBindings.count == 0);
			NSArray<id<MTLBinding>>* fragment = render.fragmentBindings;
			CHECK(fragment.count == 2);
			if (fragment.count == 2) {
				CHECK(isBinding(fragment[0], @"src", MTLBindingTypeTexture, 0));
				checkTexture(fragment[0], MTLTextureType2D, MTLDataTypeFloat, MTLBindingAccessReadOnly);
				CHECK(isBinding(fragment[1], @"offsets", MTLBindingTypeBuffer, 0));
				CHECK(((id<MTLBufferBinding>)fragment[1]).bufferDataType == MTLDataTypeStruct);
			}
		}

		// stage-in attributes are not bindings: vertex_with_inputs has three, and no resources
		render = renderReflection(vertexInputs, @"vertex_with_inputs", @"fragment_main");
		if (render != nil) {
			CHECK(render.vertexBindings != nil && render.vertexBindings.count == 0);
			CHECK(render.fragmentBindings != nil && render.fragmentBindings.count == 0);
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
