// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0
//
// Host check of the type-name to MTLDataType mapping behind MTLFunction.vertexAttributes. The
// expected numbers are MTLDataType's values from Metal's MTLArgument.h. Build and run from the
// repository root:
//
//   c++ -std=c++17 -Iprivate-include test/attribute-info/attribute-info.cpp -o attribute-info && ./attribute-info

#include <Metal/MTLAttributeInfo.h>

#include <cstdio>
#include <string>

namespace {

unsigned failures = 0;

void expectType(const char* name, unsigned long expected) {
	auto actual = MTLAttributeInfo::dataTypeFromName(name);
	bool ok = actual == expected;
	std::printf("%s \"%s\" -> %lu (expected %lu)\n", ok ? "PASS" : "FAIL", name, actual, expected);
	failures += !ok;
}

}

int main() {
	// float: Float 3, Float2-4 4-6, Float2x2 7 ... Float4x4 15
	expectType("float", 3);
	expectType("float2", 4);
	expectType("float3", 5);
	expectType("float4", 6);
	expectType("float2x2", 7);
	expectType("float2x3", 8);
	expectType("float2x4", 9);
	expectType("float3x2", 10);
	expectType("float3x3", 11);
	expectType("float4x3", 14);
	expectType("float4x4", 15);
	// half: Half 16, Half2-4 17-19, Half2x2 20 ... Half4x4 28
	expectType("half", 16);
	expectType("half3", 18);
	expectType("half2x2", 20);
	expectType("half4x4", 28);
	expectType("int", 29);
	expectType("int4", 32);
	expectType("uint", 33);
	expectType("uint2", 34);
	expectType("short", 37);
	expectType("short3", 39);
	expectType("ushort", 41);
	expectType("ushort4", 44);
	expectType("char", 45);
	expectType("char2", 46);
	expectType("uchar", 49);
	expectType("uchar4", 52);
	expectType("bool", 53);
	expectType("bool4", 56);
	expectType("long", 81);
	expectType("long4", 84);
	expectType("ulong", 85);
	expectType("ulong2", 86);

	// not guessed at
	expectType("", 0);
	expectType("float5", 0);
	expectType("float1", 0);
	expectType("float4x", 0);
	expectType("float5x2", 0);
	expectType("int2x2", 0);
	expectType("uint4x4", 0);
	expectType("packed_float3", 0);
	expectType("floaty", 0);
	expectType("MyStruct", 0);

	return failures ? 1 : 0;
}
