// Copyright (C) 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLEVENTINTERNAL_H_
#define _METAL_MTLEVENTINTERNAL_H_

#import <Metal/MTLEvent.h>
#import <Metal/MTLDevice.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

METAL_DECLARATIONS_BEGIN

// private export
MTL_EXPORT
@interface MTLEventInternal : NSObject <MTLEvent>

#if DARLING_METAL_ENABLED
- (instancetype)initWithEvent: (std::shared_ptr<Indium::Event>)event
                       device: (id<MTLDevice>)device;
- (std::shared_ptr<Indium::Event>)indiumEvent;
#endif

@end

// private export
MTL_EXPORT
@interface MTLSharedEventInternal : NSObject <MTLSharedEvent>

#if DARLING_METAL_ENABLED
- (instancetype)initWithEvent: (std::shared_ptr<Indium::SharedEvent>)event;
- (std::shared_ptr<Indium::SharedEvent>)indiumSharedEvent;
#endif

@end

#if DARLING_METAL_ENABLED
@interface MTLSharedEventHandle (Internal)

- (instancetype)initWithHandle: (std::shared_ptr<Indium::SharedEventHandle>)handle;
- (std::shared_ptr<Indium::SharedEventHandle>)indiumHandle;

@end
#endif

METAL_DECLARATIONS_END

#if DARLING_METAL_ENABLED
// The Indium event behind an event of either kind, without a message send. Empty for nil and for objects this
// framework did not create.
std::shared_ptr<Indium::Event> MTLEventGetIndium(id<MTLEvent> object);
#endif

#endif // _METAL_MTLEVENTINTERNAL_H_
