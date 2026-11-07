// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLDEVICEINFO_H_
#define _METAL_MTLDEVICEINFO_H_

// Helpers for the values MTLDevice reports about a GPU. Plain C++ (no Objective-C, Vulkan or
// Indium), so test/device-info can check them on the host.

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>

namespace MTLDeviceInfo {

// Used when the Vulkan name has no characters at all.
static constexpr const char* kFallbackName = "Vulkan Device";

static inline bool isSpace(char c) {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v';
}

// Collapses runs of whitespace into one space and trims both ends.
static inline std::string collapseWhitespace(const std::string& text) {
	std::string out;
	bool pendingSpace = false;
	for (char c: text) {
		if (isSpace(c)) {
			pendingSpace = !out.empty();
			continue;
		}
		if (pendingSpace) {
			out.push_back(' ');
			pendingSpace = false;
		}
		out.push_back(c);
	}
	return out;
}

static inline char lower(char c) {
	return (c >= 'A' && c <= 'Z') ? static_cast<char>(c - 'A' + 'a') : c;
}

// Removes "(R)" and "(TM)" in any letter case.
static inline std::string removeTrademarks(const std::string& text) {
	std::string out;
	for (size_t i = 0; i < text.size();) {
		if (text[i] == '(') {
			if (i + 2 < text.size() && lower(text[i + 1]) == 'r' && text[i + 2] == ')') {
				i += 3;
				continue;
			}
			if (i + 3 < text.size() && lower(text[i + 1]) == 't' && lower(text[i + 2]) == 'm' && text[i + 3] == ')') {
				i += 4;
				continue;
			}
		}
		out.push_back(text[i++]);
	}
	return out;
}

// Drops one trailing parenthesised group, the driver's annotation (" (RADV NAVI21)",
// " (CML GT2)", " (LLVM 19.1.7, 256 bits)"), unless it is the whole name. Expects collapsed
// whitespace.
static inline std::string removeTrailingGroup(const std::string& text) {
	if (text.empty() || text.back() != ')') {
		return text;
	}
	int depth = 0;
	for (size_t i = text.size(); i-- > 0;) {
		if (text[i] == ')') {
			++depth;
		} else if (text[i] == '(' && --depth == 0) {
			std::string prefix = collapseWhitespace(text.substr(0, i));
			return prefix.empty() ? text : prefix;
		}
	}
	return text; // unbalanced: leave it alone
}

// The name of a GPU as Metal reports it, from VkPhysicalDeviceProperties::deviceName: the
// marketing name without trademark signs or the driver's annotation, e.g.
// "AMD Radeon RX 6800 XT (RADV NAVI21)" -> "AMD Radeon RX 6800 XT".
static inline std::string metalNameFromVulkanName(const char* vulkanName) {
	std::string raw = vulkanName ? vulkanName : "";
	std::string cleaned = removeTrailingGroup(collapseWhitespace(removeTrademarks(raw)));
	if (!cleaned.empty()) {
		return cleaned;
	}
	std::string rawTrimmed = collapseWhitespace(raw);
	return rawTrimmed.empty() ? std::string(kFallbackName) : rawTrimmed;
}

// A registry ID for a device from its Vulkan device UUID. Like the IORegistry ID on macOS it is the
// same in every process and differs between devices; it is never 0.
static inline uint64_t registryIDFromUUID(const std::array<uint8_t, 16>& uuid) {
	// FNV-1a over the 16 bytes
	uint64_t hash = 0xcbf29ce484222325ull;
	for (uint8_t byte: uuid) {
		hash ^= byte;
		hash *= 0x100000001b3ull;
	}
	return hash != 0 ? hash : 1;
}

// GPU families (MTLGPUFamily values) the device reports. Only the families whose features Indium
// implements: the Mac families and the Common families every Metal GPU has. The Apple families
// (Apple-silicon features such as tile shading and imageblocks), Metal3/Metal4 and Mac Catalyst are
// not claimed.
static inline bool supportsFamily(long family) {
	switch (family) {
		case 2001: // MTLGPUFamilyMac1
		case 2002: // MTLGPUFamilyMac2
		case 3001: // MTLGPUFamilyCommon1
		case 3002: // MTLGPUFamilyCommon2
		case 3003: // MTLGPUFamilyCommon3
			return true;
		default:
			return false;
	}
}

// Feature sets (MTLFeatureSet values) the device reports: the macOS ones that the claimed families
// correspond to. iOS and tvOS feature sets are not claimed.
static inline bool supportsFeatureSet(unsigned long featureSet) {
	switch (featureSet) {
		case 10000: // MTLFeatureSet_macOS_GPUFamily1_v1
		case 10001: // MTLFeatureSet_macOS_GPUFamily1_v2
		case 10002: // MTLFeatureSet_macOS_ReadWriteTextureTier2
		case 10003: // MTLFeatureSet_macOS_GPUFamily1_v3
		case 10004: // MTLFeatureSet_macOS_GPUFamily1_v4
		case 10005: // MTLFeatureSet_macOS_GPUFamily2_v1
			return true;
		default:
			return false;
	}
}

} // namespace MTLDeviceInfo

#endif // _METAL_MTLDEVICEINFO_H_
