// Copyright (C) 2026 Lubos Dolezel
#include <metal_stdlib>
using namespace metal;

// texture_buffer: element i of the buffer is read, transformed and written to another texture buffer.
kernel void tb_read(texture_buffer<float, access::read> src [[texture(0)]],
                    device float4* out [[buffer(0)]],
                    uint i [[thread_position_in_grid]]) {
	out[i] = src.read(i);
}

kernel void tb_write(texture_buffer<float, access::write> dst [[texture(0)]],
                     uint i [[thread_position_in_grid]]) {
	dst.write(float4(i, i * 2, i * 3, 1), i);
}

kernel void tb_uint(texture_buffer<uint, access::read_write> t [[texture(0)]],
                    uint i [[thread_position_in_grid]]) {
	uint4 v = t.read(i);
	t.write(v + uint4(1, 2, 3, 4), i);
}

kernel void tb_size(texture_buffer<float, access::read> src [[texture(0)]],
                    device uint* out [[buffer(0)]],
                    uint i [[thread_position_in_grid]]) {
	out[i] = src.get_width();
}
