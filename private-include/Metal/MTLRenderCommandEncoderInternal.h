// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLRENDERCOMMANDENCODERINTERNAL_H_
#define _METAL_MTLRENDERCOMMANDENCODERINTERNAL_H_

#import <Metal/MTLRenderCommandEncoder.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

METAL_DECLARATIONS_BEGIN

#if DARLING_METAL_ENABLED
NS_INLINE
Indium::ClearColor MTLClearColorToIndium(MTLClearColor clearColor) {
	return Indium::ClearColor { clearColor.red, clearColor.green, clearColor.blue, clearColor.alpha };
};

NS_INLINE
Indium::Viewport MTLViewportToIndium(MTLViewport viewport) {
	return Indium::Viewport {
		viewport.originX,
		viewport.originY,
		viewport.width,
		viewport.height,
		viewport.znear,
		viewport.zfar,
	};
};

NS_INLINE
Indium::ScissorRect MTLScissorRectToIndium(MTLScissorRect rect) {
	return Indium::ScissorRect {
		rect.height,
		rect.width,
		rect.x,
		rect.y,
	};
};

@interface MTLRenderPassAttachmentDescriptor (Internal)

- (Indium::RenderPassAttachmentDescriptor)asIndiumDescriptor;

@end

@interface MTLRenderPassColorAttachmentDescriptor (Internal)

- (Indium::RenderPassColorAttachmentDescriptor)asIndiumDescriptor;

@end

@interface MTLRenderPassDepthAttachmentDescriptor (Internal)

- (Indium::RenderPassDepthAttachmentDescriptor)asIndiumDescriptor;

@end

@interface MTLRenderPassStencilAttachmentDescriptor (Internal)

- (Indium::RenderPassStencilAttachmentDescriptor)asIndiumDescriptor;

@end

@interface MTLRenderPassColorAttachmentDescriptorArray (Internal) <NSCopying>

- (std::unordered_map<size_t, Indium::RenderPassColorAttachmentDescriptor>)asIndiumDescriptors;

- (std::vector<Indium::RenderPassColorAttachmentDescriptor>)asContiguousIndiumDescriptors;

@end

@interface MTLRenderPassDescriptor (Internal)

- (Indium::RenderPassDescriptor)asIndiumDescriptor;

@end
#endif

#if DARLING_METAL_ENABLED
// The objects last bound to the first 32 slots of one kind (buffers, textures or samplers of one
// stage), so that binding the same object to the same slot again can be dropped.
//
// A slot is identified by the Indium object, not by the Objective-C object, because an app may
// release a Metal object while the pass still uses it and get a new one at the same address. The
// Indium encoder keeps the object bound to each slot alive until the slot is bound again or the
// encoder ends, so an Indium object's address cannot be reused while it is recorded here.
struct MTLRenderEncoderSlots {
	static constexpr NSUInteger count = 32;

	const void* objects[count] = {};
	uint32_t known = 0;

	// Returns true when `index` already holds `object`. Otherwise records `object` for `index`.
	bool holds(NSUInteger index, const void* object) {
		if (index >= count) {
			return false;
		}
		const uint32_t bit = uint32_t(1) << index;
		if ((known & bit) && objects[index] == object) {
			return true;
		}
		objects[index] = object;
		known |= bit;
		return false;
	}

	// Records `object` for `index`, for a bind that is forwarded in any case.
	void record(NSUInteger index, const void* object) {
		holds(index, object);
	}

	void forget(NSUInteger index) {
		if (index < count) {
			known &= ~(uint32_t(1) << index);
		}
	}

	void forget(NSUInteger start, NSUInteger length) {
		for (NSUInteger i = 0; i < length; ++i) {
			forget(start + i);
		}
	}
};

// The same for buffer slots, which also hold an offset.
struct MTLRenderEncoderBufferSlots : MTLRenderEncoderSlots {
	NSUInteger offsets[count] = {};

	// Returns true when `index` already holds `object` at `offset`. Otherwise records both.
	bool holds(NSUInteger index, const void* object, NSUInteger offset) {
		if (index >= count) {
			return false;
		}
		const uint32_t bit = uint32_t(1) << index;
		if ((known & bit) && objects[index] == object && offsets[index] == offset) {
			return true;
		}
		objects[index] = object;
		offsets[index] = offset;
		known |= bit;
		return false;
	}

	void record(NSUInteger index, const void* object, NSUInteger offset) {
		holds(index, object, offset);
	}

	// Returns true when the buffer bound to `index` already has `offset`. Otherwise records it.
	bool holdsOffset(NSUInteger index, NSUInteger offset) {
		if (index >= count || !(known & (uint32_t(1) << index))) {
			return false;
		}
		if (offsets[index] == offset) {
			return true;
		}
		offsets[index] = offset;
		return false;
	}
};
#endif

@interface MTLRenderCommandEncoderInternal : NSObject <MTLRenderCommandEncoder>
#if DARLING_METAL_ENABLED
{
	MTLRenderEncoderBufferSlots _vertexBufferSlots;
	MTLRenderEncoderBufferSlots _fragmentBufferSlots;
	MTLRenderEncoderSlots _vertexTextureSlots;
	MTLRenderEncoderSlots _fragmentTextureSlots;
	MTLRenderEncoderSlots _vertexSamplerSlots;
	MTLRenderEncoderSlots _fragmentSamplerSlots;
	// The pipeline state is held by the Indium encoder like the slots above.
	const void* _boundPipelineState;
	BOOL _pipelineStateKnown;
	// The Indium encoder applies a depth-stencil state without keeping it, so it is kept here
	// while it is the one bound.
	std::shared_ptr<Indium::DepthStencilState> _boundDepthStencilState;
	BOOL _depthStencilStateKnown;
}
#endif

#if DARLING_METAL_ENABLED
@property(readonly) std::shared_ptr<Indium::RenderCommandEncoder> encoder;

- (instancetype)initWithEncoder: (std::shared_ptr<Indium::RenderCommandEncoder>)encoder
                         device: (id<MTLDevice>)device;
#endif

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLRENDERCOMMANDENCODERINTERNAL_H_
