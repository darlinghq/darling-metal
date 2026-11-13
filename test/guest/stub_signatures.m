// Copyright (C) 2026 Lubos Dolezel
// Darling-specific: stub classes (MTLStencilDescriptor, MTLCaptureManager) must report a method
// signature whose argument count matches the selector, so an unimplemented selector with
// arguments reaches the stub's forwardInvocation: instead of raising NSForwardSignatureError.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static void checkClass(id obj) {
	SEL zero = NSSelectorFromString(@"noSuchMetalOption");
	SEL one = NSSelectorFromString(@"setNoSuchMetalOption:");
	SEL two = NSSelectorFromString(@"setNoSuchMetalOption:other:");

	NSMethodSignature* s0 = [obj methodSignatureForSelector: zero];
	NSMethodSignature* s1 = [obj methodSignatureForSelector: one];
	NSMethodSignature* s2 = [obj methodSignatureForSelector: two];
	CHECK(s0 != nil && [s0 numberOfArguments] == 2);
	CHECK(s1 != nil && [s1 numberOfArguments] == 3);
	CHECK(s2 != nil && [s2 numberOfArguments] == 4);

	// the call reaches the stub (which logs) instead of raising on the signature mismatch
	BOOL raised = NO;
	@try {
		[obj performSelector: one withObject: @1];
	} @catch (NSException* e) {
		raised = YES;
		printf("raised: %s\n", [[e description] UTF8String]);
	}
	CHECK(!raised);
}

int main(void) {
	@autoreleasepool {
		checkClass([[MTLStencilDescriptor alloc] init]);
		checkClass([MTLCaptureManager sharedCaptureManager]);
	}
	printf(failures ? "FAILED: %d\n" : "OK\n", failures);
	return failures != 0;
}
