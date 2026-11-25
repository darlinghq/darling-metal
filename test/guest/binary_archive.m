// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// MTLBinaryArchive: an archive made without a URL starts empty and takes the functions of compute and render
// pipeline descriptors; it can be written to a file and opened from it again. A pipeline made with
// MTLPipelineOptionFailOnBinaryArchiveMiss is created when one of its descriptor's binaryArchives holds its
// functions (the same function from another library made from the same source too) and fails otherwise;
// without the option, or without archives, the pipeline is compiled as usual. Opening a missing file, a file
// that is not an archive or a URL that is not a file's, and writing to a directory that does not exist or to
// such a URL, fail with MTLBinaryArchiveErrorInvalidFile. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static NSString* const source =
	@"#include <metal_stdlib>\nusing namespace metal;\n"
	"kernel void add_one(device uint* out [[buffer(0)]], uint gid [[thread_position_in_grid]]) {\n"
	"	out[gid] = gid + 1;\n}\n"
	"kernel void add_two(device uint* out [[buffer(0)]], uint gid [[thread_position_in_grid]]) {\n"
	"	out[gid] = gid + 2;\n}\n"
	"vertex float4 corner(uint vid [[vertex_id]]) {\n"
	"	return float4(float(vid & 1), float(vid >> 1), 0.0, 1.0);\n}\n"
	"fragment float4 red() {\n"
	"	return float4(1.0, 0.0, 0.0, 1.0);\n}\n"
	"fragment float4 green() {\n"
	"	return float4(0.0, 1.0, 0.0, 1.0);\n}\n";

// Another add_one, with other code
static NSString* const otherSource =
	@"#include <metal_stdlib>\nusing namespace metal;\n"
	"kernel void add_one(device uint* out [[buffer(0)]], uint gid [[thread_position_in_grid]]) {\n"
	"	out[gid] = gid + 3;\n}\n";

// A pipeline for `function` that may only come from `archives`; nil on a miss.
static id<MTLComputePipelineState> fromArchives(id<MTLDevice> device, id<MTLFunction> function, NSArray* archives, NSError** error) {
	MTLComputePipelineDescriptor* descriptor = [[MTLComputePipelineDescriptor new] autorelease];
	descriptor.computeFunction = function;
	descriptor.binaryArchives = archives;
	return [[device newComputePipelineStateWithDescriptor: descriptor
	                                              options: MTLPipelineOptionFailOnBinaryArchiveMiss
	                                           reflection: nil
	                                                error: error] autorelease];
}

// A render pipeline of `vertex` and `fragment` that may only come from `archives`; nil on a miss.
static id<MTLRenderPipelineState> renderFromArchives(id<MTLDevice> device, id<MTLFunction> vertex, id<MTLFunction> fragment, NSArray* archives) {
	MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor new] autorelease];
	descriptor.vertexFunction = vertex;
	descriptor.fragmentFunction = fragment;
	descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
	descriptor.binaryArchives = archives;
	NSError* error = nil;
	return [[device newRenderPipelineStateWithDescriptor: descriptor
	                                             options: MTLPipelineOptionFailOnBinaryArchiveMiss
	                                          reflection: nil
	                                               error: &error] autorelease];
}

static BOOL isInvalidFile(NSError* error) {
	return [error.domain isEqualToString: MTLBinaryArchiveDomain] && error.code == MTLBinaryArchiveErrorInvalidFile;
}

// Runs `pipeline` over 16 threads and checks that out[i] == i + expected.
static BOOL runs(id<MTLDevice> device, id<MTLComputePipelineState> pipeline, uint32_t expected) {
	enum { kThreads = 16 };
	id<MTLBuffer> out = [[device newBufferWithLength: kThreads * 4 options: MTLResourceStorageModeShared] autorelease];
	id<MTLCommandQueue> queue = [[device newCommandQueue] autorelease];
	id<MTLCommandBuffer> commands = [queue commandBuffer];
	id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
	[encoder setComputePipelineState: pipeline];
	[encoder setBuffer: out offset: 0 atIndex: 0];
	[encoder dispatchThreadgroups: MTLSizeMake(1, 1, 1) threadsPerThreadgroup: MTLSizeMake(kThreads, 1, 1)];
	[encoder endEncoding];
	[commands commit];
	[commands waitUntilCompleted];
	const uint32_t* words = [out contents];
	for (uint32_t i = 0; i < kThreads; i++) {
		if (words[i] != i + expected) {
			return NO;
		}
	}
	return YES;
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		NSError* error = nil;
		id<MTLLibrary> library = [[device newLibraryWithSource: source options: nil error: &error] autorelease];
		CHECK(library != nil);
		if (library == nil) {
			printf("library: %s\n", error.localizedDescription.UTF8String);
			printf("FAILED: %d\n", failures);
			return 1;
		}
		id<MTLFunction> addOne = [[library newFunctionWithName: @"add_one"] autorelease];
		id<MTLFunction> addTwo = [[library newFunctionWithName: @"add_two"] autorelease];

		// a descriptor without a URL makes an empty archive
		MTLBinaryArchiveDescriptor* archiveDescriptor = [[MTLBinaryArchiveDescriptor new] autorelease];
		id<MTLBinaryArchive> archive = [[device newBinaryArchiveWithDescriptor: archiveDescriptor error: &error] autorelease];
		CHECK(archive != nil);
		if (archive == nil) {
			printf("archive: %s\n", error.localizedDescription.UTF8String);
			printf("FAILED: %d\n", failures);
			return 1;
		}
		CHECK(archive.device == device);
		CHECK(archive.label == nil);
		archive.label = @"archive";
		CHECK([archive.label isEqualToString: @"archive"]);
		CHECK(fromArchives(device, addOne, @[archive], nil) == nil);

		// a function added twice is accepted
		MTLComputePipelineDescriptor* descriptor = [[MTLComputePipelineDescriptor new] autorelease];
		descriptor.computeFunction = addOne;
		CHECK([archive addComputePipelineFunctionsWithDescriptor: descriptor error: &error]);
		CHECK([archive addComputePipelineFunctionsWithDescriptor: descriptor error: &error]);

		// the archive serves the functions added to it, and only those
		id<MTLComputePipelineState> hit = fromArchives(device, addOne, @[archive], &error);
		CHECK(hit != nil && runs(device, hit, 1));
		error = nil;
		CHECK(fromArchives(device, addTwo, @[archive], &error) == nil);
		CHECK(error != nil);
		// with no archives to look in, the option has no effect
		CHECK(fromArchives(device, addTwo, @[], nil) != nil);
		CHECK(fromArchives(device, addTwo, nil, nil) != nil);
		CHECK([[device newComputePipelineStateWithFunction: addTwo options: MTLPipelineOptionFailOnBinaryArchiveMiss reflection: nil error: &error] autorelease] != nil);

		// without the option, a function missing from the archives is compiled
		descriptor.computeFunction = addTwo;
		descriptor.binaryArchives = @[archive];
		id<MTLComputePipelineState> compiled = [[device newComputePipelineStateWithDescriptor: descriptor options: MTLPipelineOptionNone reflection: nil error: &error] autorelease];
		CHECK(compiled != nil && runs(device, compiled, 2));

		// written to a file and opened again, the archive serves the same functions
		char directory[] = "/tmp/binary_archive.XXXXXX";
		if (mkdtemp(directory) == NULL) {
			printf("FAIL: no temporary directory\n");
			return 1;
		}
		NSURL* url = [NSURL fileURLWithPath: [NSString stringWithFormat: @"%s/archive.metallib", directory]];
		CHECK([archive serializeToURL: url error: &error]);
		NSNumber* size = nil;
		CHECK([url getResourceValue: &size forKey: NSURLFileSizeKey error: nil] && size.unsignedLongLongValue > 0);

		archiveDescriptor.url = url;
		id<MTLBinaryArchive> reloaded = [[device newBinaryArchiveWithDescriptor: archiveDescriptor error: &error] autorelease];
		CHECK(reloaded != nil);
		hit = fromArchives(device, addOne, @[reloaded], &error);
		CHECK(hit != nil && runs(device, hit, 1));
		CHECK(fromArchives(device, addTwo, @[reloaded], nil) == nil);
		CHECK(fromArchives(device, addTwo, @[reloaded, archive], nil) == nil);
		id<MTLBinaryArchive> empty = [[device newBinaryArchiveWithDescriptor: [[MTLBinaryArchiveDescriptor new] autorelease] error: &error] autorelease];
		CHECK(fromArchives(device, addOne, @[empty, reloaded], nil) != nil);

		// the same function from another library made from the same source, but not one with other code
		id<MTLLibrary> again = [[device newLibraryWithSource: source options: nil error: &error] autorelease];
		id<MTLFunction> addOneAgain = [[again newFunctionWithName: @"add_one"] autorelease];
		CHECK(fromArchives(device, addOneAgain, @[reloaded], nil) != nil);
		id<MTLLibrary> other = [[device newLibraryWithSource: otherSource options: nil error: &error] autorelease];
		id<MTLFunction> otherAddOne = [[other newFunctionWithName: @"add_one"] autorelease];
		CHECK(otherAddOne != nil && fromArchives(device, otherAddOne, @[reloaded], nil) == nil);

		// what is added to a reloaded archive is served and written as well
		descriptor.computeFunction = addTwo;
		CHECK([reloaded addComputePipelineFunctionsWithDescriptor: descriptor error: &error]);
		CHECK(fromArchives(device, addTwo, @[reloaded], nil) != nil);
		NSURL* url2 = [NSURL fileURLWithPath: [NSString stringWithFormat: @"%s/archive2.metallib", directory]];
		CHECK([reloaded serializeToURL: url2 error: &error]);
		archiveDescriptor.url = url2;
		id<MTLBinaryArchive> reloaded2 = [[device newBinaryArchiveWithDescriptor: archiveDescriptor error: &error] autorelease];
		CHECK(reloaded2 != nil);
		CHECK(fromArchives(device, addOne, @[reloaded2], nil) != nil);
		CHECK(fromArchives(device, addTwo, @[reloaded2], nil) != nil);

		// a file that is missing or is not an archive cannot be opened
		error = nil;
		archiveDescriptor.url = [NSURL fileURLWithPath: [NSString stringWithFormat: @"%s/missing.metallib", directory]];
		CHECK([device newBinaryArchiveWithDescriptor: archiveDescriptor error: &error] == nil);
		CHECK(isInvalidFile(error));
		NSURL* garbage = [NSURL fileURLWithPath: [NSString stringWithFormat: @"%s/garbage.metallib", directory]];
		CHECK([[@"not an archive" dataUsingEncoding: NSUTF8StringEncoding] writeToURL: garbage atomically: NO]);
		error = nil;
		archiveDescriptor.url = garbage;
		CHECK([device newBinaryArchiveWithDescriptor: archiveDescriptor error: &error] == nil);
		CHECK(isInvalidFile(error));
		NSURL* web = [NSURL URLWithString: @"https://example.com/archive.metallib"];
		error = nil;
		archiveDescriptor.url = web;
		CHECK([device newBinaryArchiveWithDescriptor: archiveDescriptor error: &error] == nil);
		CHECK(isInvalidFile(error));

		// the directory of the destination has to exist, and be a file's
		error = nil;
		NSURL* nowhere = [NSURL fileURLWithPath: [NSString stringWithFormat: @"%s/missing/archive.metallib", directory]];
		CHECK(![archive serializeToURL: nowhere error: &error]);
		CHECK(isInvalidFile(error));
		error = nil;
		CHECK(![archive serializeToURL: web error: &error]);
		CHECK(isInvalidFile(error));

		// a render pipeline's functions; one with a fragment function not in the archive misses
		id<MTLFunction> corner = [[library newFunctionWithName: @"corner"] autorelease];
		id<MTLFunction> red = [[library newFunctionWithName: @"red"] autorelease];
		id<MTLFunction> green = [[library newFunctionWithName: @"green"] autorelease];
		id<MTLBinaryArchive> renderArchive = [[device newBinaryArchiveWithDescriptor: [[MTLBinaryArchiveDescriptor new] autorelease] error: &error] autorelease];
		CHECK(renderFromArchives(device, corner, red, @[renderArchive]) == nil);
		MTLRenderPipelineDescriptor* renderDescriptor = [[MTLRenderPipelineDescriptor new] autorelease];
		renderDescriptor.vertexFunction = corner;
		renderDescriptor.fragmentFunction = red;
		renderDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		CHECK([renderArchive addRenderPipelineFunctionsWithDescriptor: renderDescriptor error: &error]);
		CHECK(renderFromArchives(device, corner, red, @[renderArchive]) != nil);
		CHECK(renderFromArchives(device, corner, green, @[renderArchive]) == nil);

		[[NSFileManager defaultManager] removeItemAtPath: @(directory) error: nil];
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
