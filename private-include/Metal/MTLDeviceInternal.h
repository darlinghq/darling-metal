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

#ifndef _METAL_MTLDEVICEINTERNAL_H_
#define _METAL_MTLDEVICEINTERNAL_H_

#import <Metal/MTLDevice.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

void MTLDeviceDestroyAll(void);

@interface MTLDeviceInternal : NSObject <MTLDevice>

#if DARLING_METAL_ENABLED
@property(readonly) std::shared_ptr<Indium::Device> device;

- (instancetype)initWithDevice: (std::shared_ptr<Indium::Device>)device;

- (void)stopPolling;

- (void)waitUntilPollingIsStopped;
#endif

@end

#endif // _METAL_MTLDEVICEINTERNAL_H_
