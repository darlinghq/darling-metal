// SPDX-FileCopyrightText: 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLDiagnostics.h>

#if DARLING_METAL_ENABLED

#import <Metal/MTLDeviceInternal.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>

static BOOL logStatistics = NO;
static BOOL timePipelines = NO;

// A boolean (or number) stored for `key` in the org.darlinghq.Metal domain, NO when it is absent or of another type.
static BOOL copyDiagnosticsBool(CFStringRef key) {
	CFPropertyListRef value = CFPreferencesCopyAppValue(key, CFSTR("org.darlinghq.Metal"));
	if (!value) {
		return NO;
	}
	BOOL result = NO;
	if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
		result = CFBooleanGetValue((CFBooleanRef)value);
	} else if (CFGetTypeID(value) == CFNumberGetTypeID()) {
		long long number = 0;
		result = CFNumberGetValue((CFNumberRef)value, kCFNumberLongLongType, &number) && number != 0;
	}
	CFRelease(value);
	return result;
}

static NSArray<MTLDeviceInternal*>* summaryDevices = nil;

static void logSummaryAtExit(void) {
	MTLDiagnosticsLogSummary(summaryDevices);
}

void MTLDiagnosticsConfigure(NSArray<MTLDeviceInternal*>* devices) {
	logStatistics = copyDiagnosticsBool(CFSTR("LogStatistics"));
	timePipelines = copyDiagnosticsBool(CFSTR("PipelineTiming"));
	if (timePipelines) {
		for (MTLDeviceInternal* device in devices) {
			device.device->setPipelineTimingEnabled(true);
		}
	}
	if (logStatistics || timePipelines) {
		// the list lives for the life of the process, and the summary is printed from an exit handler rather than
		// from the teardown of the framework, which is not run for every way a process can end
		summaryDevices = [devices retain];
		atexit(logSummaryAtExit);
	}
}

void MTLDiagnosticsLogSummary(NSArray<MTLDeviceInternal*>* devices) {
	if (!logStatistics && !timePipelines) {
		return;
	}

	// The summary goes to stderr: it was asked for with a setting, and a command line tool or a terminal shows it
	// where the system log of the guest is not at hand.
	for (MTLDeviceInternal* device in devices) {
		const auto& indiumDevice = device.device;
		// a device nothing was created on has no Vulkan device, and nothing to report
		auto stats = indiumDevice->statistics();
		auto timings = indiumDevice->pipelineTimings();
		if (stats.totalAllocations == 0 && stats.totalHeaps == 0 && timings.empty()) {
			continue;
		}
		const char* name = indiumDevice->name().c_str();
		fprintf(stderr, "Metal statistics (%s): allocated %llu bytes (peak %llu) in %llu allocations (%llu made, %llu bytes in total), "
			"%llu memory objects live (%llu made); %llu heaps live holding %llu bytes (%llu made)\n",
			name, (unsigned long long)stats.allocatedBytes, (unsigned long long)stats.peakAllocatedBytes,
			(unsigned long long)stats.liveAllocations, (unsigned long long)stats.totalAllocations,
			(unsigned long long)stats.totalAllocatedBytes, (unsigned long long)stats.liveMemoryObjects,
			(unsigned long long)stats.totalMemoryObjects, (unsigned long long)stats.liveHeaps,
			(unsigned long long)stats.liveHeapBytes, (unsigned long long)stats.totalHeaps);
		for (const auto& timing: timings) {
			fprintf(stderr, "Metal pipeline timing (%s): %s: %llu ns of GPU time in %llu spans\n", name, timing.name.c_str(),
				(unsigned long long)timing.gpuNanoseconds, (unsigned long long)timing.spans);
		}
	}
}

#endif
