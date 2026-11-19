// SPDX-FileCopyrightText: 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLIOSURFACECOPY_H_
#define _METAL_MTLIOSURFACECOPY_H_

#if DARLING_METAL_ENABLED
#include <IOSurface/IOSurfaceRef.h>
#include <indium/indium.hpp>
#include <memory>
#include <mutex>
#include <vector>

// A texture that holds a copy of an IOSurface plane, for when the plane's memory cannot be the
// texture's storage (no DMA-BUF). The copy is kept in step with the surface the way OpenGL keeps
// its textures: the plane is uploaded when the texture is created and before GPU use once the
// CPU has written the surface (its seed changed), and GPU results are copied into the surface
// before CPU access, through IOSurface's writeback callback on lock. A CPU write is newer than
// GPU work made before it, so the writeback leaves a surface the CPU has written since alone.
struct MTLIOSurfaceCopy;

// Starts keeping `texture` (a Shared texture of the plane's size and pixel size) in step with
// the plane, and uploads the plane. The caller keeps `surface` alive until
// MTLIOSurfaceCopyDestroy.
MTLIOSurfaceCopy* MTLIOSurfaceCopyCreate(std::shared_ptr<Indium::Texture> texture, IOSurfaceRef surface, size_t plane);
void MTLIOSurfaceCopyDestroy(MTLIOSurfaceCopy* copy);

// Uploads the planes of every copy whose surface the CPU wrote since. Called before command
// buffers are committed.
void MTLIOSurfaceCopyBeforeGPUUse();

// The same for one copy, before the texture's contents are read or written directly.
void MTLIOSurfaceCopyBeforeTextureAccess(MTLIOSurfaceCopy* copy);

// Records that the GPU, or a direct write to a texture, may have changed copies since, so that
// the next lock copies them into their surfaces.
void MTLIOSurfaceCopyGPUMayHaveWritten();

// Reporting the writes of command buffers to IOSurface. Rendering into a texture of a surface
// becomes visible to every user of the surface when the command buffer that made it completes
// (the point at which GL rendering also changes the seed), so that is when it is reported.

// A surface a command buffer may write, and whether it is written through a copy (reported with
// _IOSurfaceGPUDidWrite, which the writeback callback later copies in) or through the surface's
// own memory (_IOSurfaceGPUDidWriteMemory).
struct MTLIOSurfaceWrite {
	IOSurfaceRef surface;
	bool viaCopy;
};

// The surfaces a command buffer and its encoders may write, shared between them. The surfaces
// are retained.
struct MTLIOSurfaceWriteSet {
	std::mutex mutex;
	std::vector<MTLIOSurfaceWrite> writes;

	MTLIOSurfaceWriteSet() = default;
	MTLIOSurfaceWriteSet(const MTLIOSurfaceWriteSet&) = delete;
	~MTLIOSurfaceWriteSet();
	void add(IOSurfaceRef surface, bool viaCopy);
};

// Registers this framework's callbacks with IOSurface, once. Needed by every texture of a surface.
void MTLIOSurfaceCopyRegisterCallbacks();

// Records, as the command buffer is committed, the surfaces it may write. They are retained
// until the buffer completes.
void MTLIOSurfaceCopyCommitted(const std::shared_ptr<Indium::CommandBuffer>& buffer, const std::vector<MTLIOSurfaceWrite>& writes);

// Reports the writes of a committed command buffer that has completed, once.
void MTLIOSurfaceCopyCompleted(const std::shared_ptr<Indium::CommandBuffer>& buffer);
#endif

#endif // _METAL_MTLIOSURFACECOPY_H_
