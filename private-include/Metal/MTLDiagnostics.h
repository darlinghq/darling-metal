// SPDX-FileCopyrightText: 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLDIAGNOSTICS_H_
#define _METAL_MTLDIAGNOSTICS_H_

#import <Foundation/Foundation.h>

#if DARLING_METAL_ENABLED

@class MTLDeviceInternal;

/**
 * Opt-in diagnostics, switched on in the org.darlinghq.Metal defaults domain (both off when the keys are absent):
 *  - LogStatistics (boolean): when the process exits, print each device's allocation and heap statistics to stderr;
 *  - PipelineTiming (boolean): time the GPU work of each pipeline with Vulkan timestamps and print the totals
 *    together with the statistics (also when LogStatistics is not set).
 * The settings are read once, when the device list is made.
 */
void MTLDiagnosticsConfigure(NSArray<MTLDeviceInternal*>* devices);

/** Prints the summary if one of the settings asked for it. Registered with atexit by MTLDiagnosticsConfigure(). */
void MTLDiagnosticsLogSummary(NSArray<MTLDeviceInternal*>* devices);

#endif

#endif
