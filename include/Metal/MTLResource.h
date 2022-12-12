/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _METAL_MTLRESOURCE_H_
#define _METAL_MTLRESOURCE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;

typedef NS_ENUM(NSUInteger, MTLCPUCacheMode) {
	MTLCPUCacheModeDefaultCache = 0,
	MTLCPUCacheModeWriteCombined = 1,
};

typedef NS_ENUM(NSUInteger, MTLStorageMode) {
	MTLStorageModeShared = 0,
	MTLStorageModeManaged = 1,
	MTLStorageModePrivate = 2,
	MTLStorageModeMemoryless = 3,
};

typedef NS_ENUM(NSUInteger, MTLHazardTrackingMode) {
	MTLHazardTrackingModeDefault = 0,
	MTLHazardTrackingModeUntracked = 1,
	MTLHazardTrackingModeTracked = 2,
};

#define MTLResourceCPUCacheModeShift 0
#define MTLResourceStorageModeShift 4
#define MTLResourceHazardTrackingModeShift 8

typedef NS_OPTIONS(NSUInteger, MTLResourceOptions) {
	MTLResourceCPUCacheModeDefaultCache = MTLCPUCacheModeDefaultCache << MTLResourceCPUCacheModeShift,
	MTLResourceCPUCacheModeWriteCombined = MTLCPUCacheModeWriteCombined << MTLResourceCPUCacheModeShift,

	MTLResourceStorageModeShared = MTLStorageModeShared << MTLResourceStorageModeShift,
	MTLResourceStorageModeManaged = MTLStorageModeManaged << MTLResourceStorageModeShift,
	MTLResourceStorageModePrivate = MTLStorageModePrivate << MTLResourceStorageModeShift,
	MTLResourceStorageModeMemoryless = MTLStorageModeMemoryless << MTLResourceStorageModeShift,

	MTLResourceHazardTrackingModeDefault = MTLHazardTrackingModeDefault << MTLResourceHazardTrackingModeShift,
	MTLResourceHazardTrackingModeTracked = MTLHazardTrackingModeTracked << MTLResourceHazardTrackingModeShift,
	MTLResourceHazardTrackingModeUntracked = MTLHazardTrackingModeUntracked << MTLResourceHazardTrackingModeShift,
};

@protocol MTLResource <NSObject>

@property(readonly) id<MTLDevice> device;
@property(readonly) MTLCPUCacheMode cpuCacheMode;
@property(readonly) MTLStorageMode storageMode;
@property(readonly) MTLHazardTrackingMode hazardTrackingMode;
@property(readonly) MTLResourceOptions resourceOptions;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRESOURCE_H_
