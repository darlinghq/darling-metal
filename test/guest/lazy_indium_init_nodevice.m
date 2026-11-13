// Copyright (C) 2026 Lubos Dolezel
// Darling-specific: a process that links Metal.framework but never asks for a device starts no
// Vulkan backend and exits with status 0 (the exit-time teardown tolerates a backend that never ran).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

int main(void) {
	@autoreleasepool {
		return NSClassFromString(@"MTLCompileOptions") != Nil ? 0 : 1;
	}
}
