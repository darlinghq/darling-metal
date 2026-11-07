// SPDX-FileCopyrightText: 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLIOSURFACECOPY_H_
#define _METAL_MTLIOSURFACECOPY_H_

#if DARLING_METAL_ENABLED
#include <IOSurface/IOSurfaceRef.h>
#include <indium/indium.hpp>

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
#endif

#endif // _METAL_MTLIOSURFACECOPY_H_
