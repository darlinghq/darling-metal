// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0
//
// Host check of the helpers behind -[MTLDevice name], registryID, supportsFamily: and
// supportsFeatureSet:. Build and run from the repository root:
//
//   c++ -std=c++17 -Iprivate-include test/device-info/device-info.cpp -o device-info && ./device-info

#include <Metal/MTLDeviceInfo.h>

#include <cstdio>
#include <string>

namespace {

unsigned failures = 0;

void report(bool ok, const std::string& what) {
	std::printf("%s %s\n", ok ? "PASS" : "FAIL", what.c_str());
	failures += !ok;
}

void expectName(const char* vulkan, const char* expected) {
	auto actual = MTLDeviceInfo::metalNameFromVulkanName(vulkan);
	report(actual == expected, std::string("name \"") + (vulkan ? vulkan : "(null)") + "\" -> \"" + actual + "\" (expected \"" + expected + "\")");
}

}

int main() {
	expectName("AMD Radeon RX 6800 XT (RADV NAVI21)", "AMD Radeon RX 6800 XT");
	expectName("AMD Radeon Graphics (RADV RENOIR)", "AMD Radeon Graphics");
	expectName("Intel(R) UHD Graphics 630 (CML GT2)", "Intel UHD Graphics 630");
	expectName("Intel(R) Arc(TM) A770 Graphics (DG2)", "Intel Arc A770 Graphics");
	expectName("NVIDIA GeForce RTX 4090", "NVIDIA GeForce RTX 4090");
	expectName("llvmpipe (LLVM 19.1.7, 256 bits)", "llvmpipe");
	expectName("  AMD   Radeon\tRX 7900 XTX  (RADV NAVI31) ", "AMD Radeon RX 7900 XTX");
	expectName("Foo GPU (driver (nested) x)", "Foo GPU");
	expectName("Foo (Bar) GPU", "Foo (Bar) GPU");
	expectName("(RADV NAVI21)", "(RADV NAVI21)");
	expectName("Broken (unbalanced", "Broken (unbalanced");
	expectName("(R)(TM)", "(R)(TM)");
	expectName("   ", MTLDeviceInfo::kFallbackName);
	expectName("", MTLDeviceInfo::kFallbackName);
	expectName(nullptr, MTLDeviceInfo::kFallbackName);

	std::array<uint8_t, 16> a {};
	std::array<uint8_t, 16> b {};
	b[15] = 1;
	report(MTLDeviceInfo::registryIDFromUUID(a) != 0 && MTLDeviceInfo::registryIDFromUUID(b) != 0, "registry IDs are non-zero");
	report(MTLDeviceInfo::registryIDFromUUID(a) != MTLDeviceInfo::registryIDFromUUID(b), "different UUIDs give different registry IDs");
	report(MTLDeviceInfo::registryIDFromUUID(b) == MTLDeviceInfo::registryIDFromUUID(b), "a UUID always gives the same registry ID");

	// MTLGPUFamily values from Metal's MTLDevice.h
	bool families = true;
	for (long family: { 2001L, 2002L, 3001L, 3002L, 3003L }) {
		families = families && MTLDeviceInfo::supportsFamily(family);
	}
	for (long family: { 0L, 1001L, 1007L, 1011L, 2003L, 3004L, 4001L, 4002L, 5001L, 5002L, -1L }) {
		families = families && !MTLDeviceInfo::supportsFamily(family);
	}
	report(families, "Mac1, Mac2 and Common1-3 only");

	// MTLFeatureSet values from Metal's MTLDevice.h
	bool featureSets = true;
	for (unsigned long featureSet = 10000; featureSet <= 10005; ++featureSet) {
		featureSets = featureSets && MTLDeviceInfo::supportsFeatureSet(featureSet);
	}
	for (unsigned long featureSet: { 0UL, 16UL, 9999UL, 10006UL, 30000UL }) {
		featureSets = featureSets && !MTLDeviceInfo::supportsFeatureSet(featureSet);
	}
	report(featureSets, "the macOS feature sets only");

	return failures ? 1 : 0;
}
