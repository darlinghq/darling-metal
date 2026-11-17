// Copyright (C) 2026 Lubos Dolezel
// -[MTLDevice newBufferWithBytesNoCopy:length:options:deallocator:]: a shared buffer over page-aligned memory the
// application owns. contents is the pointer, what the CPU writes is what the GPU reads and the other way round, and
// the deallocator is called once, with the pointer and length, after the buffer is released and the GPU is done with
// it; a creation that fails (here a zero length) does not call it. The expectations follow the documented contract and
// what macOS 27.0.1 (Apple silicon) does (checked by compiling this file there).
// macOS 27.0.1 on Apple silicon also accepts pointers that are not page-aligned (and a null pointer); Darling returns nil
// for those, as the documented contract allows, so that check runs on Darling only.
// Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdatomic.h>
#include <sys/mman.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static BOOL onDarling(void) { return NSClassFromString(@"MTLTextureInternal") != nil; }

static atomic_int deallocCount;
static void* _Atomic deallocPointer;
static atomic_ulong deallocLength;

static void (^recordDealloc(void))(void*, NSUInteger) {
	return [[^(void* pointer, NSUInteger length) {
		deallocPointer = pointer;
		deallocLength = length;
		atomic_fetch_add(&deallocCount, 1);
	} copy] autorelease];
}

static BOOL eventually(BOOL (^condition)(void)) {
	for (int i = 0; i < 5000; i++) {
		if (condition()) return YES;
		usleep(2000);
	}
	return NO;
}

int main(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device == nil) {
			printf("SKIP: no Metal device\n");
			return 77;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
		const size_t page = (size_t)getpagesize();
		char* memory = mmap(NULL, 8 * page, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
		CHECK(memory != MAP_FAILED);

		// --- the buffer is the memory
		{
			deallocCount = 0;
			id<MTLBuffer> buffer = [device newBufferWithBytesNoCopy: memory length: 2 * page options: MTLResourceStorageModeShared deallocator: recordDealloc()];
			CHECK(buffer != nil);
			CHECK([buffer contents] == memory);
			CHECK([buffer length] == 2 * page);
			CHECK(buffer.storageMode == MTLStorageModeShared);
			memory[5] = 7;
			CHECK(((char*)[buffer contents])[5] == 7);
			((char*)[buffer contents])[9] = 3;
			CHECK(memory[9] == 3);
			CHECK(atomic_load(&deallocCount) == 0);
			[buffer release];
			CHECK(eventually(^BOOL { return atomic_load(&deallocCount) == 1; }));
			usleep(20000);
			CHECK(atomic_load(&deallocCount) == 1);
			CHECK(deallocPointer == memory && atomic_load(&deallocLength) == 2 * page);
		}

		// --- a length that is not a whole number of pages
		{
			deallocCount = 0;
			id<MTLBuffer> buffer = [device newBufferWithBytesNoCopy: memory length: page + 1 options: MTLResourceStorageModeShared deallocator: recordDealloc()];
			CHECK(buffer != nil && [buffer length] == page + 1 && [buffer contents] == memory);
			[buffer release];
			CHECK(eventually(^BOOL { return atomic_load(&deallocCount) == 1; }));
			CHECK(atomic_load(&deallocLength) == page + 1);
		}

		// --- no deallocator
		{
			memory[0] = 42;
			id<MTLBuffer> buffer = [device newBufferWithBytesNoCopy: memory length: page options: MTLResourceStorageModeShared deallocator: nil];
			CHECK(buffer != nil);
			[buffer release];
			CHECK(memory[0] == 42);
		}

		// --- a refused creation gives nil and does not call the deallocator
		{
			deallocCount = 0;
			id<MTLBuffer> buffer = [device newBufferWithBytesNoCopy: memory length: 0 options: MTLResourceStorageModeShared deallocator: recordDealloc()];
			CHECK(buffer == nil);
			if (onDarling()) {
				buffer = [device newBufferWithBytesNoCopy: memory + 16 length: page options: MTLResourceStorageModeShared deallocator: recordDealloc()];
				CHECK(buffer == nil);
			}
			usleep(50000);
			CHECK(atomic_load(&deallocCount) == 0);
		}

		// --- the GPU reads what the CPU wrote and its writes show in the memory
		{
			char* mine = memory + 2 * page;
			memset(mine, 0x11, page);
			id<MTLBuffer> noCopy = [device newBufferWithBytesNoCopy: mine length: page options: MTLResourceStorageModeShared deallocator: nil];
			id<MTLBuffer> other = [device newBufferWithLength: page options: MTLResourceStorageModeShared];
			memset([other contents], 0x22, page);
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
			[blit copyFromBuffer: noCopy sourceOffset: 0 toBuffer: other destinationOffset: 0 size: page / 2];
			[blit fillBuffer: noCopy range: NSMakeRange(page / 2, page / 2) value: 0x77];
			[blit endEncoding];
			[commands commit];
			[commands waitUntilCompleted];
			const unsigned char* theirs = [other contents];
			CHECK(theirs[0] == 0x11 && theirs[page / 2 - 1] == 0x11 && theirs[page / 2] == 0x22);
			CHECK((unsigned char)mine[0] == 0x11 && (unsigned char)mine[page / 2 - 1] == 0x11);
			CHECK((unsigned char)mine[page / 2] == 0x77 && (unsigned char)mine[page - 1] == 0x77);
			[noCopy release];
			[other release];
		}

		// --- the deallocator waits for the GPU: the buffer is released while a command buffer that uses it is held
		// back by an event the CPU signals later
		{
			deallocCount = 0;
			char* held = memory + 4 * page;
			id<MTLSharedEvent> event = [device newSharedEvent];
			id<MTLBuffer> buffer = [device newBufferWithBytesNoCopy: held length: page options: MTLResourceStorageModeShared deallocator: recordDealloc()];
			id<MTLCommandBuffer> commands = [queue commandBuffer];
			[commands encodeWaitForEvent: event value: 1];
			id<MTLBlitCommandEncoder> blit = [commands blitCommandEncoder];
			[blit fillBuffer: buffer range: NSMakeRange(0, page) value: 0x33];
			[blit endEncoding];
			[commands commit];
			[buffer release];
			usleep(300000);
			CHECK(atomic_load(&deallocCount) == 0);
			event.signaledValue = 1;
			[commands waitUntilCompleted];
			CHECK(eventually(^BOOL { return atomic_load(&deallocCount) == 1; }));
			CHECK((unsigned char)held[0] == 0x33 && (unsigned char)held[page - 1] == 0x33);
			[event release];
		}

		munmap(memory, 8 * page);
	}
	if (failures) {
		printf("FAILED (%d)\n", failures);
		return 1;
	}
	printf("ALL PASSED\n");
	return 0;
}
