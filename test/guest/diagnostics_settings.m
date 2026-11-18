// Copyright (C) 2026 Lubos Dolezel
// The opt-in diagnostics of Darling's Metal, switched on in the org.darlinghq.Metal defaults domain:
//  - with no setting, a process that uses Metal prints no summary when it exits;
//  - LogStatistics prints each device's allocation statistics (to stderr) at exit;
//  - PipelineTiming also times the GPU work of each pipeline and prints the totals by pipeline name.
// The test starts itself as a child that makes a buffer and runs one compute dispatch, and reads the child's stderr.
// Darling only: macOS has neither setting, so the test exits 77 there. Exits 77 when there is no Metal device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <mach-o/dyld.h>
#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char** environ;

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static int child(void) {
	@autoreleasepool {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (!device) {
			return 77;
		}
		id<MTLBuffer> buffer = [device newBufferWithLength: 1 << 20 options: MTLResourceStorageModeShared];
		NSError* error = nil;
		id<MTLLibrary> library = [device newLibraryWithSource: @"kernel void fill(device uint* a [[buffer(0)]], uint i [[thread_position_in_grid]]) { a[i] = i; }"
		                                              options: nil error: &error];
		id<MTLFunction> function = [library newFunctionWithName: @"fill"];
		id<MTLComputePipelineState> state = [device newComputePipelineStateWithFunction: function error: &error];
		if (!state) {
			return 78;
		}
		id<MTLCommandQueue> queue = [device newCommandQueue];
		id<MTLCommandBuffer> commands = [queue commandBuffer];
		id<MTLComputeCommandEncoder> encoder = [commands computeCommandEncoder];
		[encoder setComputePipelineState: state];
		[encoder setBuffer: buffer offset: 0 atIndex: 0];
		[encoder dispatchThreads: MTLSizeMake(64, 1, 1) threadsPerThreadgroup: MTLSizeMake(64, 1, 1)];
		[encoder endEncoding];
		[commands commit];
		[commands waitUntilCompleted];
		// the timestamps are read when the command buffer retires, just after the wait returns
		usleep(300000);
		[function release];
		[state release];
		[library release];
		[buffer release];
	}
	return 0;
}

// Runs this program as the child, returns its stderr in `output` and the exit status.
static int runChild(NSString** output) {
	char path[4096];
	uint32_t size = sizeof(path);
	_NSGetExecutablePath(path, &size);
	int fds[2];
	pipe(fds);
	posix_spawn_file_actions_t actions;
	posix_spawn_file_actions_init(&actions);
	posix_spawn_file_actions_adddup2(&actions, fds[1], 2);
	posix_spawn_file_actions_addclose(&actions, fds[0]);
	char* argv[] = { path, (char*)"--child", NULL };
	pid_t pid;
	if (posix_spawn(&pid, path, &actions, NULL, argv, environ) != 0) {
		return -1;
	}
	close(fds[1]);
	NSMutableData* data = [NSMutableData data];
	char buffer[4096];
	ssize_t n;
	while ((n = read(fds[0], buffer, sizeof(buffer))) > 0) {
		[data appendBytes: buffer length: n];
	}
	close(fds[0]);
	int status = 0;
	waitpid(pid, &status, 0);
	posix_spawn_file_actions_destroy(&actions);
	*output = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
	return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

static void setSettings(BOOL logStatistics, BOOL pipelineTiming) {
	CFStringRef domain = CFSTR("org.darlinghq.Metal");
	CFPreferencesSetAppValue(CFSTR("LogStatistics"), logStatistics ? kCFBooleanTrue : NULL, domain);
	CFPreferencesSetAppValue(CFSTR("PipelineTiming"), pipelineTiming ? kCFBooleanTrue : NULL, domain);
	CFPreferencesAppSynchronize(domain);
}

int main(int argc, char** argv) {
	if (argc > 1 && !strcmp(argv[1], "--child")) {
		return child();
	}
	@autoreleasepool {
		if (NSClassFromString(@"MTLDeviceInternal") == nil) {
			printf("SKIP Darling only\n");
			return 77;
		}
		NSString* output = nil;

		setSettings(NO, NO);
		int status = runChild(&output);
		if (status == 77) {
			printf("SKIP no Metal device\n");
			return 77;
		}
		CHECK(status == 0);
		CHECK([output rangeOfString: @"Metal statistics"].location == NSNotFound);
		CHECK([output rangeOfString: @"Metal pipeline timing"].location == NSNotFound);

		setSettings(YES, NO);
		status = runChild(&output);
		CHECK(status == 0);
		CHECK([output rangeOfString: @"Metal statistics ("].location != NSNotFound);
		CHECK([output rangeOfString: @" allocations ("].location != NSNotFound);
		CHECK([output rangeOfString: @"Metal pipeline timing"].location == NSNotFound);

		setSettings(NO, YES);
		status = runChild(&output);
		CHECK(status == 0);
		CHECK([output rangeOfString: @"Metal pipeline timing ("].location != NSNotFound);
		CHECK([output rangeOfString: @": compute fill: "].location != NSNotFound);
		CHECK([output rangeOfString: @" in 1 spans"].location != NSNotFound);

		setSettings(NO, NO);
		status = runChild(&output);
		CHECK([output rangeOfString: @"Metal statistics"].location == NSNotFound);
	}
	printf("%s\n", failures ? "FAILED" : "ALL PASSED");
	return failures ? 1 : 0;
}
