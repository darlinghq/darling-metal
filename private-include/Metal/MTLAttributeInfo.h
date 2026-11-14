// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLATTRIBUTEINFO_H_
#define _METAL_MTLATTRIBUTEINFO_H_

// The MTLDataType of a stage-in attribute from the type name the shader compiler records for it
// ("float4", "uint2", "half3", "float2x2"). Plain C++ (no Objective-C or Indium), so
// test/attribute-info can check it on the host. The numbers are MTLDataType's values.

#include <cstddef>
#include <string>

namespace MTLAttributeInfo {

static constexpr unsigned long kDataTypeNone = 0;

struct ScalarType {
	const char* name;
	unsigned long first; // the scalar; its 2-, 3- and 4-component vectors follow it
	bool hasMatrices;    // float and half only: the matrices follow the vectors
};

static constexpr ScalarType kScalarTypes[] = {
	{ "float", 3, true },    // MTLDataTypeFloat, Float2-4, Float2x2 to Float4x4
	{ "half", 16, true },    // MTLDataTypeHalf, Half2-4, Half2x2 to Half4x4
	{ "int", 29, false },    // MTLDataTypeInt, Int2-4
	{ "uint", 33, false },
	{ "short", 37, false },
	{ "ushort", 41, false },
	{ "char", 45, false },
	{ "uchar", 49, false },
	{ "bool", 53, false },
	{ "long", 81, false },
	{ "ulong", 85, false },
};

static inline bool isDimension(char c) {
	return c >= '2' && c <= '4';
}

// MTLDataTypeNone for a name that is not a scalar, vector or (float and half) matrix type: an
// unknown name is not guessed at.
static inline unsigned long dataTypeFromName(const std::string& name) {
	for (const auto& type: kScalarTypes) {
		std::string base(type.name);
		if (name.compare(0, base.size(), base) != 0) {
			continue;
		}
		auto rest = name.substr(base.size());
		if (rest.empty()) {
			return type.first;
		}
		if (rest.size() == 1 && isDimension(rest[0])) {
			return type.first + (rest[0] - '1');
		}
		if (type.hasMatrices && rest.size() == 3 && isDimension(rest[0]) && rest[1] == 'x' && isDimension(rest[2])) {
			// columns x rows, in the order Float2x2, Float2x3, Float2x4, Float3x2, ...
			return type.first + 4 + (rest[0] - '2') * 3 + (rest[2] - '2');
		}
	}
	return kDataTypeNone;
}

} // namespace MTLAttributeInfo

#endif // _METAL_MTLATTRIBUTEINFO_H_
