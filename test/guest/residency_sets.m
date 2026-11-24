// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

// MTLResidencySetDescriptor and MTLResidencySet: the descriptor's defaults and copies, a new set, staged additions
// and removals and what -commit changes, the size of resources made from a heap, and sets attached to a command
// queue and a command buffer that then runs.
// The expectations follow Apple's documentation, except where the comments say otherwise, and were checked on
// macOS 27 (Apple M1).
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static BOOL holds(id<MTLResidencySet> set, NSArray* allocations) {
	NSArray* all = set.allAllocations;
	if (all.count != allocations.count) {
		return NO;
	}
	for (id allocation in allocations) {
		if ([all indexOfObjectIdenticalTo: allocation] == NSNotFound || ![set containsAllocation: allocation]) {
			return NO;
		}
	}
	return YES;
}

int main(void) {
	@autoreleasepool {
		// --- the descriptor
		MTLResidencySetDescriptor* descriptor = [[MTLResidencySetDescriptor new] autorelease];
		CHECK(descriptor.label == nil && descriptor.initialCapacity == 0);
		descriptor.label = @"set";
		descriptor.initialCapacity = 2;
		MTLResidencySetDescriptor* copy = [[descriptor copy] autorelease];
		CHECK(copy != descriptor && [copy.label isEqualToString: @"set"] && copy.initialCapacity == 2);
		descriptor.initialCapacity = 3;
		CHECK(copy.initialCapacity == 2);

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}

		// --- a new set
		NSError* error = nil;
		id<MTLResidencySet> set = [device newResidencySetWithDescriptor: descriptor error: &error];
		CHECK(set != nil && error == nil);
		CHECK(set.device == device);
		// the documentation says the set takes the descriptor's label; on macOS 27 (Apple M1) it is nil
		CHECK(set.label == nil || [set.label isEqualToString: @"set"]);
		descriptor.label = @"other";
		CHECK(set.label == nil || [set.label isEqualToString: @"set"]);
		CHECK(set.allocationCount == 0 && set.allocatedSize == 0 && set.allAllocations.count == 0);

		id<MTLBuffer> first = [device newBufferWithLength: 400 options: MTLResourceStorageModeShared];
		id<MTLBuffer> second = [device newBufferWithLength: 1024 options: MTLResourceStorageModeShared];
		CHECK(![set containsAllocation: first]);

		// --- staged changes
		// allAllocations, containsAllocation: and allocationCount include staged additions (as Apple's header says),
		// allocatedSize changes on -commit.
		// QUIRK: until -commit, allocationCount still counts allocations staged to be removed.
		NSArray* before = set.allAllocations;
		[set addAllocation: first];
		[set addAllocation: first];
		CHECK(before.count == 0);
		CHECK(holds(set, @[first]));
		CHECK(set.allocationCount == 1 && set.allocatedSize == 0);
		[set commit];
		CHECK(holds(set, @[first]));
		CHECK(set.allocationCount == 1 && set.allocatedSize >= first.allocatedSize && set.allocatedSize > 0);
		uint64_t firstSize = set.allocatedSize;

		[set removeAllocation: first];
		CHECK(holds(set, @[]));
		CHECK(set.allocationCount == 1 && set.allocatedSize == firstSize);
		[set commit];
		CHECK(set.allocationCount == 0 && set.allocatedSize == 0);

		[set addAllocation: first];
		[set removeAllocation: first];
		CHECK(holds(set, @[]) && set.allocationCount == 0);
		[set commit];
		CHECK(set.allocationCount == 0 && set.allocatedSize == 0);

		[set addAllocation: first];
		[set commit];
		[set addAllocation: second];
		CHECK(holds(set, @[first, second]) && set.allocationCount == 2);
		[set removeAllocation: first];
		CHECK(holds(set, @[second]) && set.allocationCount == 2);
		[set commit];
		CHECK(holds(set, @[second]) && set.allocationCount == 1 && set.allocatedSize > 0);

		[set removeAllAllocations];
		[set addAllocation: first];
		CHECK(holds(set, @[first]) && set.allocationCount == 2);
		[set commit];
		CHECK(holds(set, @[first]) && set.allocationCount == 1);
		[set removeAllAllocations];
		[set commit];
		CHECK(holds(set, @[]) && set.allocationCount == 0 && set.allocatedSize == 0);

		id<MTLAllocation> both[2] = { first, second };
		[set addAllocations: both count: 2];
		CHECK(holds(set, @[first, second]) && set.allocationCount == 2 && set.allocatedSize == 0);
		[set commit];
		CHECK(set.allocationCount == 2 && set.allocatedSize >= first.allocatedSize + second.allocatedSize);
		[set requestResidency];
		[set endResidency];
		[set removeAllocations: both count: 2];
		CHECK(holds(set, @[]) && set.allocationCount == 2 && set.allocatedSize > 0);
		[set commit];
		CHECK(set.allocationCount == 0 && set.allocatedSize == 0);

		// --- resources made from a heap make the whole heap resident
		MTLHeapDescriptor* heapDescriptor = [[MTLHeapDescriptor new] autorelease];
		heapDescriptor.size = 1 << 20;
		heapDescriptor.storageMode = MTLStorageModePrivate;
		id<MTLHeap> heap = [device newHeapWithDescriptor: heapDescriptor];
		CHECK(heap != nil);
		id<MTLBuffer> inHeap1 = [heap newBufferWithLength: 256 options: MTLResourceStorageModePrivate];
		id<MTLBuffer> inHeap2 = [heap newBufferWithLength: 256 options: MTLResourceStorageModePrivate];
		CHECK(inHeap1 != nil && inHeap2 != nil);
		[set addAllocation: inHeap1];
		[set addAllocation: inHeap2];
		[set commit];
		CHECK(set.allocationCount == 2 && set.allocatedSize >= heap.size);
		uint64_t heapSize = set.allocatedSize;
		[set addAllocation: heap];
		[set commit];
		CHECK(set.allocationCount == 3 && set.allocatedSize == heapSize);
		[set removeAllAllocations];
		[set commit];

		// --- attached to a queue and a command buffer
		[set addAllocation: first];
		[set commit];
		id<MTLCommandQueue> queue = [device newCommandQueue];
		[queue addResidencySet: set];
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		[commands useResidencySet: set];
		id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
		[blit fillBuffer: first range: NSMakeRange(0, 400) value: 0x5a];
		[blit endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		CHECK(commands.status == MTLCommandBufferStatusCompleted);
		CHECK(((uint8_t*)first.contents)[399] == 0x5a);
		[queue removeResidencySet: set];

		[queue release];
		[inHeap1 release];
		[inHeap2 release];
		[heap release];
		[first release];
		[second release];
		[set release];
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
