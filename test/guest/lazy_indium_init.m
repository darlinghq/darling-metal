// Copyright (C) 2026 Lubos Dolezel
// Darling-specific: loading Metal.framework must not start the Vulkan backend. Indium dlopens
// libvulkan when it initialises, so the library must be absent from the process until the first
// device is requested, and a process that never requests one must still exit cleanly (the exit-time
// teardown has to tolerate a backend that was never started).
// Exits 77 when /proc/self/maps cannot be read.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>
#include <string.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

// returns 1 if a library whose path contains `needle` is mapped, 0 if not, -1 if unreadable
static int mapped(const char* needle) {
	FILE* f = fopen("/proc/self/maps", "r");
	if (!f) {
		return -1;
	}
	char line[4096];
	int found = 0;
	while (fgets(line, sizeof(line), f)) {
		if (strstr(line, needle)) {
			found = 1;
			break;
		}
	}
	fclose(f);
	return found;
}

int main(void) {
	@autoreleasepool {
		// make sure the framework really is loaded
		CHECK(NSClassFromString(@"MTLCompileOptions") != Nil);
		int before = mapped("libvulkan");
		if (before < 0) {
			printf("SKIP: cannot read /proc/self/maps\n");
			return 77;
		}
		CHECK(before == 0);

		// asking for a device is what starts the backend; without a Vulkan driver there is none
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		int after = mapped("libvulkan");
		printf("device=%s libvulkan mapped after request=%d\n", device ? "yes" : "no", after);
		if (device != nil) {
			CHECK(after == 1);
		}
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
