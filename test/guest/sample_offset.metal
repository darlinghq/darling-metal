// Copyright (C) 2026 Lubos Dolezel
//
// Functions of sample_offset_metallib.h (compiled with Apple's metal compiler: `xcrun -sdk macosx metal -c`, then
// `metallib`, then `xxd -i -n sample_offset_metallib`): sample() and gather() with texel offsets that the compiled
// AIR does not pass as a constant. The compiler keeps a loop over offsets as a loop, so the offset is built from the
// loop counter at run time, and an offset may also come from a buffer or from the fragment's position.

#include <metal_stdlib>
using namespace metal;

constexpr sampler nearestClamp(coord::normalized, address::clamp_to_edge, filter::nearest, mip_filter::nearest);

struct Offsets {
	int2 offset;
	int radius;
};

struct Position {
	float4 position [[position]];
};

// a triangle that covers the whole target
vertex Position cover(uint vid [[vertex_id]]) {
	Position out;
	float2 corner = float2((vid << 1) & 2, vid & 2);
	out.position = float4(corner * 2.0 - 1.0, 0.0, 1.0);
	return out;
}

// the centre of the texel under the fragment, for a target of the texture's size
static float2 texelCentre(Position in, texture2d<float> src) {
	return in.position.xy / float2(src.get_width(), src.get_height());
}

// an offset from a buffer
fragment float4 sample_buffer_offset(Position in [[stage_in]], texture2d<float> src [[texture(0)]], constant Offsets& offsets [[buffer(0)]]) {
	return src.sample(nearestClamp, texelCentre(in, src), offsets.offset);
}

// a fixed number of taps: the offset comes from the counter of a loop the compiler does not unroll
fragment float4 sample_loop_offset(Position in [[stage_in]], texture2d<float> src [[texture(0)]]) {
	float4 sum = 0;
	for (int i = -2; i <= 2; i++) {
		sum += src.sample(nearestClamp, texelCentre(in, src), int2(i, 1));
	}
	return sum;
}

// a number of taps from a buffer
fragment float4 sample_radius_offset(Position in [[stage_in]], texture2d<float> src [[texture(0)]], constant Offsets& offsets [[buffer(0)]]) {
	float4 sum = 0;
	for (int i = -offsets.radius; i <= offsets.radius; i++) {
		sum += src.sample(nearestClamp, texelCentre(in, src), int2(0, i));
	}
	return sum;
}

// an offset that differs between neighbouring fragments; the level of detail still follows the coordinates
fragment float4 sample_varying_offset(Position in [[stage_in]], texture2d<float> src [[texture(0)]]) {
	int2 pixel = int2(in.position.xy);
	return src.sample(nearestClamp, texelCentre(in, src), int2(pixel.x % 3 - 1, pixel.y % 2));
}

// sampling in a kernel (an explicit level) with an offset from a buffer
kernel void sample_kernel_offset(texture2d<float> src [[texture(0)]], device float4* out [[buffer(0)]], constant Offsets& offsets [[buffer(1)]], uint2 gid [[thread_position_in_grid]]) {
	float2 coordinate = (float2(gid) + 0.5) / float2(src.get_width(), src.get_height());
	out[gid.y * src.get_width() + gid.x] = src.sample(nearestClamp, coordinate, level(0), offsets.offset);
}

// a gather at the middle of the texels (x, y) to (x + 1, y + 1), moved by an offset from a buffer
kernel void gather_kernel_offset(texture2d<float> src [[texture(0)]], device float4* out [[buffer(0)]], constant Offsets& offsets [[buffer(1)]], uint2 gid [[thread_position_in_grid]]) {
	float2 coordinate = (float2(gid) + 0.75) / float2(src.get_width(), src.get_height());
	out[gid.y * src.get_width() + gid.x] = src.gather(nearestClamp, coordinate, offsets.offset, component::x);
}
