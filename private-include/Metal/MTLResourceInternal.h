// SPDX-FileCopyrightText: 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLRESOURCEINTERNAL_H_
#define _METAL_MTLRESOURCEINTERNAL_H_

#import <Metal/MTLResource.h>
#import <Metal/MTLHeap.h>

#if DARLING_METAL_ENABLED
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLHeapInternal.h>
#include <vector>

// The Indium resource behind a buffer or texture, or null for any other object. Resources the encoders are told
// about with useResource: and memoryBarrierWithResources: are converted with these.
NS_INLINE
std::shared_ptr<Indium::Resource> MTLResourceGetIndium(id<MTLResource> object) {
	if (object == nil) {
		return nullptr;
	}
	if (auto& buffer = MTLBufferGetIndium((id<MTLBuffer>)object)) {
		return buffer;
	}
	if (auto& texture = MTLTextureGetIndium((id<MTLTexture>)object)) {
		return texture;
	}
	return nullptr;
};

NS_INLINE
std::vector<std::shared_ptr<Indium::Resource>> MTLResourcesGetIndium(const id<MTLResource> __nonnull* objects, NSUInteger count) {
	std::vector<std::shared_ptr<Indium::Resource>> result;
	result.reserve(count);
	for (NSUInteger i = 0; i < count; ++i) {
		if (auto resource = MTLResourceGetIndium(objects[i])) {
			result.push_back(std::move(resource));
		}
	}
	return result;
};

NS_INLINE
std::vector<std::shared_ptr<Indium::Heap>> MTLHeapsGetIndium(const id<MTLHeap> __nonnull* objects, NSUInteger count) {
	std::vector<std::shared_ptr<Indium::Heap>> result;
	result.reserve(count);
	for (NSUInteger i = 0; i < count; ++i) {
		if (auto& heap = MTLHeapGetIndium(objects[i])) {
			result.push_back(heap);
		}
	}
	return result;
};

#endif

#endif // _METAL_MTLRESOURCEINTERNAL_H_
