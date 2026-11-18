// Copyright (C) 2026 Lubos Dolezel
#include <metal_stdlib>
using namespace metal;

// Non-inlined helpers.
struct Pair { int a; float b; };

[[gnu::noinline]] static int add3(int x, int y, int z) { return x + y * 2 + z * 3; }
[[gnu::noinline]] static float4 scale4(float4 v, float s) { return v * s + float4(1, 2, 3, 4); }
[[gnu::noinline]] static void bump(device int* p, int n) { p[0] += n; p[1] = p[0] * 2; }
[[gnu::noinline]] static int sum_ptr(const device int* p, uint n) {
	int s = 0;
	for (uint k = 0; k < n; k++) s += p[k];
	return s;
}
[[gnu::noinline]] static float pair_eval(Pair p, int m) { return float(p.a * m) + p.b; }
[[gnu::noinline]] static Pair pair_make(int a, float b) { Pair r; r.a = a + 1; r.b = b * 2; return r; }
[[gnu::noinline]] static int nested(int x) { return add3(x, x, 1) + 1; }
[[gnu::noinline]] static void ref_inc(thread int& r) { r += 10; }

kernel void call_helpers(device int* ints [[buffer(0)]],
                         device float4* vecs [[buffer(1)]],
                         device float* floats [[buffer(2)]],
                         uint i [[thread_position_in_grid]]) {
	int base = int(i);
	ints[i * 4 + 0] = add3(base, 2, 3);
	vecs[i] = scale4(float4(base, 1, 2, 3), 2.0f);
	ints[i * 4 + 1] = sum_ptr(ints + 64, 4);
	Pair p = pair_make(base, 1.5f);
	floats[i] = pair_eval(p, 3);
	ints[i * 4 + 2] = nested(base);
	int local = base;
	ref_inc(local);
	ints[i * 4 + 3] = local;
	if (i == 0) bump(ints + 128, 5);
}
