// Copyright (C) 2026 Lubos Dolezel
//
// Kernels of air_coverage_2_metallib.h (compiled with Apple's metal compiler: `xcrun -sdk macosx metal -c`, then
// `metallib`, then `xxd -i -n air_coverage_2_metallib`): gather() of a 2D texture, size and level count queries,
// read() of a multisample texture and the simdgroup functions.

#include <metal_stdlib>
using namespace metal;

constexpr sampler nearestClamp(coord::normalized, address::clamp_to_edge, filter::nearest);

// gathers at the middle of the four texels (x, y) to (x + 1, y + 1); the size comes in a buffer
kernel void gather_2d(texture2d<float> src [[texture(0)]], device float4* out [[buffer(0)]], constant uint2& size [[buffer(1)]], uint2 gid [[thread_position_in_grid]]) {
	float2 coordinate = (float2(gid) + 0.75) / float2(size);
	out[gid.y * size.x + gid.x] = src.gather(nearestClamp, coordinate, int2(0), component::y);
}

kernel void gather_2d_offset(texture2d<float> src [[texture(0)]], device float4* out [[buffer(0)]], constant uint2& size [[buffer(1)]], uint2 gid [[thread_position_in_grid]]) {
	float2 coordinate = (float2(gid) + 0.75) / float2(size);
	out[gid.y * size.x + gid.x] = src.gather(nearestClamp, coordinate, int2(1, 0), component::x);
}

kernel void size_2d(texture2d<float> t [[texture(0)]], device uint* o [[buffer(0)]]) {
	o[0] = t.get_width();
	o[1] = t.get_height();
	o[2] = t.get_width(1);
	o[3] = t.get_num_mip_levels();
}

kernel void ms_read(texture2d_ms<float, access::read> src [[texture(0)]], device float4* out [[buffer(0)]], constant uint& samples [[buffer(1)]], uint2 gid [[thread_position_in_grid]]) {
	for (uint s = 0; s < samples; ++s) {
		out[(gid.y * 4 + gid.x) * samples + s] = src.read(gid, s);
	}
}

kernel void ms_sizes(texture2d_ms<float, access::read> src [[texture(0)]], device uint* out [[buffer(0)]]) {
	out[0] = src.get_width();
	out[1] = src.get_height();
	out[2] = src.get_num_samples();
}

kernel void simd_ops(device uint* out [[buffer(0)]], uint t [[thread_position_in_threadgroup]], uint lane [[thread_index_in_simdgroup]], uint width [[threads_per_simdgroup]]) {
	out[t * 8] = lane;
	out[t * 8 + 1] = width;
	out[t * 8 + 2] = simd_sum(t);
	out[t * 8 + 3] = simd_max(t);
	out[t * 8 + 4] = simd_prefix_exclusive_sum(t);
	out[t * 8 + 5] = simd_broadcast_first(t);
	out[t * 8 + 6] = simd_shuffle(t, ushort((lane + 1) % width));
	out[t * 8 + 7] = uint(ulong(simd_ballot((lane & 1) != 0)));
}
