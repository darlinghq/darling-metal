// SPDX-FileCopyrightText: 2026 Lubos Dolezel
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLIOSurfaceCopy.h>

#if DARLING_METAL_ENABLED
#import <IOSurface/IOSurfaceRef.h>
#import <IOSurface/IOSurfacePriv.h>
#import <IOKit/IOReturn.h>

#include <algorithm>
#include <atomic>
#include <mutex>
#include <vector>

struct MTLIOSurfaceCopy {
	std::shared_ptr<Indium::Texture> texture;
	IOSurfaceRef surface;
	size_t plane;
	// The surface's seed when the texture and the plane last held the same contents.
	uint32_t seed;
	// g_generation when they did.
	uint64_t generation;
};

// Every live copy. Recursive, because an upload locks its surface, which calls the writeback
// callback on the same thread.
static std::recursive_mutex g_copiesMutex;
static std::vector<MTLIOSurfaceCopy*> g_copies;

// Raised whenever the GPU or a direct texture write may have changed a copy. A copy whose
// generation is current holds nothing the surface lacks.
static std::atomic<uint64_t> g_generation { 1 };

static void* planeBase(IOSurfaceRef surface, size_t plane)
{
	return IOSurfaceGetPlaneCount(surface) == 0 ? IOSurfaceGetBaseAddress(surface) : IOSurfaceGetBaseAddressOfPlane(surface, plane);
}

static size_t planeBytesPerRow(IOSurfaceRef surface, size_t plane)
{
	return IOSurfaceGetPlaneCount(surface) == 0 ? IOSurfaceGetBytesPerRow(surface) : IOSurfaceGetBytesPerRowOfPlane(surface, plane);
}

static Indium::Region textureRegion(const MTLIOSurfaceCopy* copy)
{
	return Indium::Region::make2D(0, 0, copy->texture->width(), copy->texture->height());
}

// Copies the plane into the texture. Called with g_copiesMutex held.
static void upload(MTLIOSurfaceCopy* copy)
{
	uint64_t generation = g_generation.load();
	if (IOSurfaceLock(copy->surface, kIOSurfaceLockReadOnly, nullptr) != kIOReturnSuccess) {
		return;
	}
	try {
		copy->texture->replaceRegion(textureRegion(copy), 0, planeBase(copy->surface, copy->plane), planeBytesPerRow(copy->surface, copy->plane));
		copy->seed = IOSurfaceGetSeed(copy->surface);
		copy->generation = generation;
	} catch (const std::exception&) {
		// Left stale; the next use tries again.
	}
	IOSurfaceUnlock(copy->surface, kIOSurfaceLockReadOnly, nullptr);
}

// Whether the CPU has written the surface since the texture last matched it.
static bool cpuWroteSince(const MTLIOSurfaceCopy* copy)
{
	return IOSurfaceGetSeed(copy->surface) != copy->seed;
}

// IOSurface's writeback callback: copies GPU results into the surface before the CPU or another
// process sees it, unless the CPU has written the surface since (its contents are newer) or
// nothing may have changed the texture. The copy happens under a lock of its own, which marks the
// surface modified, as GPU rendering into it does.
static void writeBack(IOSurfaceRef surface)
{
	std::lock_guard lock(g_copiesMutex);
	for (auto copy: g_copies) {
		if (copy->surface != surface || cpuWroteSince(copy) || copy->generation == g_generation.load()) {
			continue;
		}
		uint64_t generation = g_generation.load();
		if (IOSurfaceLock(surface, 0, nullptr) != kIOReturnSuccess) {
			continue;
		}
		uint32_t seed = 0;
		try {
			copy->texture->getBytes(textureRegion(copy), 0, planeBase(surface, copy->plane), planeBytesPerRow(surface, copy->plane));
		} catch (const std::exception&) {
			// The surface keeps what it had.
		}
		IOSurfaceUnlock(surface, 0, &seed);
		copy->seed = seed;
		copy->generation = generation;
	}
}

// Committed command buffers that may write surfaces and have not been reported yet.
struct PendingWrites {
	std::shared_ptr<Indium::CommandBuffer> buffer;
	std::vector<MTLIOSurfaceWrite> writes;
};
static std::mutex g_pendingMutex;
static std::vector<PendingWrites> g_pending;

void MTLIOSurfaceCopyCommitted(const std::shared_ptr<Indium::CommandBuffer>& buffer, const std::vector<MTLIOSurfaceWrite>& writes)
{
	if (writes.empty()) {
		return;
	}
	PendingWrites pending { buffer, writes };
	for (const auto& write: pending.writes) {
		CFRetain(write.surface);
	}
	std::lock_guard lock(g_pendingMutex);
	g_pending.push_back(std::move(pending));
}

void MTLIOSurfaceCopyCompleted(const std::shared_ptr<Indium::CommandBuffer>& buffer)
{
	PendingWrites done;
	{
		std::lock_guard lock(g_pendingMutex);
		auto it = std::find_if(g_pending.begin(), g_pending.end(), [&](const PendingWrites& entry) { return entry.buffer == buffer; });
		if (it == g_pending.end()) {
			return;
		}
		done = std::move(*it);
		g_pending.erase(it);
	}
	// Reported without a lock of ours held: IOSurface may call back into the writeback.
	for (const auto& write: done.writes) {
		if (write.viaCopy) {
			_IOSurfaceGPUDidWrite(write.surface);
		} else {
			_IOSurfaceGPUDidWriteMemory(write.surface);
		}
		CFRelease(write.surface);
	}
}

// IOSurface's finish callback, for a lock that must not wait for rendering through copies: waits
// for the command buffers already submitted that write the surface's own memory, and reports
// them. Copies are neither written back nor waited for.
static void finish(IOSurfaceRef surface)
{
	std::vector<std::shared_ptr<Indium::CommandBuffer>> buffers;
	{
		std::lock_guard lock(g_pendingMutex);
		for (const auto& entry: g_pending) {
			for (const auto& write: entry.writes) {
				if (write.surface == surface && !write.viaCopy) {
					buffers.push_back(entry.buffer);
					break;
				}
			}
		}
	}
	for (const auto& buffer: buffers) {
		buffer->waitUntilCompleted();
		MTLIOSurfaceCopyCompleted(buffer);
	}
}

MTLIOSurfaceWriteSet::~MTLIOSurfaceWriteSet()
{
	for (const auto& write: writes) {
		CFRelease(write.surface);
	}
}

void MTLIOSurfaceWriteSet::add(IOSurfaceRef surface, bool viaCopy)
{
	std::lock_guard lock(mutex);
	for (const auto& write: writes) {
		if (write.surface == surface && write.viaCopy == viaCopy) {
			return;
		}
	}
	writes.push_back({ (IOSurfaceRef) CFRetain(surface), viaCopy });
}

void MTLIOSurfaceCopyRegisterCallbacks()
{
	static std::once_flag once;
	std::call_once(once, []() {
		static const _IOSurfaceGPUCallbacks callbacks = {
			.version = _IOSURFACE_GPU_CALLBACKS_VERSION_REPORTS_WRITES,
			.writeback = writeBack,
			// Every copy retains its surface, so none is freed while a copy has state for it.
			.forget = nullptr,
			.finish = finish,
		};
		_IOSurfaceSetGPUCallbacks(&callbacks);
	});
}

MTLIOSurfaceCopy* MTLIOSurfaceCopyCreate(std::shared_ptr<Indium::Texture> texture, IOSurfaceRef surface, size_t plane)
{
	MTLIOSurfaceCopyRegisterCallbacks();
	auto copy = new MTLIOSurfaceCopy { std::move(texture), surface, plane, 0, 0 };
	std::lock_guard lock(g_copiesMutex);
	upload(copy);
	if (copy->generation == 0) {
		delete copy;
		return nullptr;
	}
	g_copies.push_back(copy);
	return copy;
}

void MTLIOSurfaceCopyDestroy(MTLIOSurfaceCopy* copy)
{
	if (copy == nullptr) {
		return;
	}
	{
		std::lock_guard lock(g_copiesMutex);
		g_copies.erase(std::remove(g_copies.begin(), g_copies.end(), copy), g_copies.end());
	}
	delete copy;
}

void MTLIOSurfaceCopyBeforeGPUUse()
{
	std::lock_guard lock(g_copiesMutex);
	for (auto copy: g_copies) {
		if (cpuWroteSince(copy)) {
			upload(copy);
		}
	}
}

void MTLIOSurfaceCopyBeforeTextureAccess(MTLIOSurfaceCopy* copy)
{
	std::lock_guard lock(g_copiesMutex);
	if (cpuWroteSince(copy)) {
		upload(copy);
	}
}

void MTLIOSurfaceCopyGPUMayHaveWritten()
{
	g_generation.fetch_add(1);
}
#endif
