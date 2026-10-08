// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLMSLReflection.h>
#import <Metal/stubs.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdarg.h>
#include <cmath>
#include <initializer_list>

#if DARLING_METAL_ENABLED

// Schema: mslc c745234 src/sema.cpp resource and embedded sampler emission.
// Descriptor sets are stage-owned in Indium; embedded sampler indices are local
// to each entry point. Buffer-only version 2 documents remain supported.

static NSString* MTLReflectionError(NSString* format, ...) {
	va_list args;
	va_start(args, format);
	NSString* reason = [[NSString alloc] initWithFormat: format arguments: args];
	va_end(args);
	return [reason autorelease];
}

// A JSON number that is not an integer. Reading 2.5 as 2 would put a binding at
// an index the shader never asked for, so it is refused rather than rounded.
static bool MTLReadIndex(id value, size_t& outIndex) {
	if (![value isKindOfClass: [NSNumber class]] ||
		value == (id)kCFBooleanTrue || value == (id)kCFBooleanFalse) {
		return false;
	}

	if (CFNumberIsFloatType((CFNumberRef)value)) {
		return false;
	}

	long long read = [value longLongValue];

	if (read < 0) {
		return false;
	}

	outIndex = (size_t)read;
	return true;
}

static bool MTLReadString(NSDictionary* object, NSString* key, NSString*& outValue) {
	id value = [object objectForKey: key];

	if (![value isKindOfClass: [NSString class]]) {
		return false;
	}

	outValue = (NSString*)value;
	return true;
}

static bool MTLReadStageType(NSString* stage, Indium::FunctionType& outType) {
	if ([stage isEqualToString: @"compute"]) {
		outType = Indium::FunctionType::Kernel;
	} else if ([stage isEqualToString: @"vertex"]) {
		outType = Indium::FunctionType::Vertex;
	} else if ([stage isEqualToString: @"fragment"]) {
		outType = Indium::FunctionType::Fragment;
	} else {
		return false;
	}

	return true;
}

template<typename T>
static bool MTLReadEnum(NSDictionary* object, NSString* key, T& value,
	std::initializer_list<std::pair<NSString*, T>> names)
{
	NSString* name = nil;
	if (!MTLReadString(object, key, name)) return false;
	for (const auto& item : names) {
		if ([name isEqualToString: item.first]) {
			value = item.second;
			return true;
		}
	}
	return false;
}

static bool MTLReadLOD(id value, float& outValue) {
	if (![value isKindOfClass: [NSNumber class]] ||
		value == (id)kCFBooleanTrue || value == (id)kCFBooleanFalse) return false;
	double number = [value doubleValue];
	outValue = (float)number;
	return std::isfinite(number) && std::isfinite(outValue) && number >= 0;
}

static bool MTLReadEmbeddedSamplers(id entries, Indium::FunctionReflection& function,
	NSString*& error)
{
	if (entries == nil) return true;
	if (![entries isKindOfClass: [NSArray class]]) {
		error = MTLReflectionError(@"embedded_samplers is not an array");
		return false;
	}
	using Sampler = Indium::EmbeddedSamplerDescriptor;
	for (id entry in (NSArray*)entries) {
		if (![entry isKindOfClass: [NSDictionary class]]) {
			error = MTLReflectionError(@"an embedded sampler is not an object");
			return false;
		}
		NSDictionary* object = entry;
		Sampler sampler;
		auto address = [&](NSString* key, Sampler::AddressMode& mode) {
			return MTLReadEnum(object, key, mode, {
				{@"ClampToZero", Sampler::AddressMode::ClampToZero},
				{@"ClampToEdge", Sampler::AddressMode::ClampToEdge},
				{@"Repeat", Sampler::AddressMode::Repeat},
				{@"MirrorRepeat", Sampler::AddressMode::MirrorRepeat}});
		};
		auto filter = [&](NSString* key, Sampler::Filter& mode) {
			return MTLReadEnum(object, key, mode, {
				{@"Nearest", Sampler::Filter::Nearest}, {@"Linear", Sampler::Filter::Linear}});
		};
		id normalized = [object objectForKey: @"normalized_coordinates"];
		size_t anisotropy = 0;
		NSString* compare = nil;
		NSString* border = nil;
		if (!address(@"s_address", sampler.widthAddressMode) ||
			!address(@"t_address", sampler.heightAddressMode) ||
			!address(@"r_address", sampler.depthAddressMode) ||
			!filter(@"mag_filter", sampler.magnificationFilter) ||
			!filter(@"min_filter", sampler.minificationFilter) ||
			!MTLReadEnum(object, @"mip_filter", sampler.mipmapFilter, {
				{@"None", Sampler::MipFilter::None}, {@"Nearest", Sampler::MipFilter::Nearest},
				{@"Linear", Sampler::MipFilter::Linear}}) ||
			(normalized != (id)kCFBooleanTrue && normalized != (id)kCFBooleanFalse) ||
			!MTLReadString(object, @"compare_function", compare) || ![compare isEqualToString: @"Never"] ||
			!MTLReadString(object, @"border_color", border) || ![border isEqualToString: @"TransparentBlack"] ||
			!MTLReadIndex([object objectForKey: @"anisotropy"], anisotropy) || anisotropy != 1 ||
			!MTLReadLOD([object objectForKey: @"lod_min"], sampler.lodMin) ||
			!MTLReadLOD([object objectForKey: @"lod_max"], sampler.lodMax) || sampler.lodMin > sampler.lodMax)
		{
			error = MTLReflectionError(@"an embedded sampler has missing or unsupported state");
			return false;
		}
		sampler.usesNormalizedCoordinates = normalized == (id)kCFBooleanTrue;
		sampler.compareFunction = Sampler::CompareFunction::Never;
		sampler.borderColor = Sampler::BorderColor::TransparentBlack;
		sampler.anisotropyLevel = (uint8_t)anisotropy;
		function.embeddedSamplers.push_back(sampler);
	}
	return true;
}

static bool MTLReadBindings(NSArray* bindings, Indium::FunctionReflection& outFunction,
	NSString*& outError)
{
	for (id entry in bindings) {
		if (![entry isKindOfClass: [NSDictionary class]]) {
			outError = MTLReflectionError(@"a reflection binding is not an object");
			return false;
		}

		NSDictionary* object = (NSDictionary*)entry;
		Indium::BindingDescriptor binding;

		NSString* kind = nil;
		if (!MTLReadString(object, @"kind", kind)) {
			outError = MTLReflectionError(@"a reflection binding has no string kind");
			return false;
		}

		if ([kind isEqualToString: @"Buffer"]) binding.type = Indium::BindingType::Buffer;
		else if ([kind isEqualToString: @"Texture"]) binding.type = Indium::BindingType::Texture;
		else if ([kind isEqualToString: @"Sampler"]) binding.type = Indium::BindingType::Sampler;
		else {
			outError = MTLReflectionError(@"unsupported reflection binding kind '%@'", kind);
			return false;
		}

		id embedded = [object objectForKey: @"embedded_sampler"];
		if (embedded != nil) {
			if (binding.type != Indium::BindingType::Sampler ||
				[object objectForKey: @"metal_index"] != nil ||
				!MTLReadIndex(embedded, binding.embeddedSamplerIndex) ||
				binding.embeddedSamplerIndex >= outFunction.embeddedSamplers.size())
			{
				outError = MTLReflectionError(@"invalid embedded sampler binding");
				return false;
			}
			binding.index = SIZE_MAX;
		} else if (!MTLReadIndex([object objectForKey: @"metal_index"], binding.index)) {
			outError = MTLReflectionError(@"binding '%@' has no integer metal_index", kind);
			return false;
		}
		if (binding.type == Indium::BindingType::Texture &&
			!MTLReadEnum(object, @"texture_access", binding.textureAccessType, {
				{@"Sample", Indium::TextureAccessType::Sample}, {@"Write", Indium::TextureAccessType::Write}}))
		{
			outError = MTLReflectionError(@"texture binding has missing or unsupported texture_access");
			return false;
		}

		id descriptor = [object objectForKey: @"descriptor"];
		if (![descriptor isKindOfClass: [NSDictionary class]]) {
			outError = MTLReflectionError(@"binding '%@' has no descriptor object", kind);
			return false;
		}

		// Only the binding number is read. The set is not, because indium builds
		// the descriptor set layout for the function's stage itself and ignores
		// it for buffers, whose addresses all arrive through the one uniform
		// buffer it binds for the stage.
		if (!MTLReadIndex([(NSDictionary*)descriptor objectForKey: @"binding"],
			binding.internalIndex))
		{
			outError = MTLReflectionError(@"binding '%@' has no integer descriptor binding number", kind);
			return false;
		}

		if (binding.type != Indium::BindingType::Buffer) {
			size_t set = 0;
			size_t expected = outFunction.functionType == Indium::FunctionType::Fragment ? 1 : 0;
			if (!MTLReadIndex([(NSDictionary*)descriptor objectForKey: @"set"], set) || set != expected) {
				outError = MTLReflectionError(@"resource descriptor set does not match its stage");
				return false;
			}
		}
		outFunction.bindings.push_back(binding);
	}

	return true;
}

bool MTLReadMSLReflection(const char* document, size_t length,
	Indium::LibraryReflection& outReflection, NSString*& outError)
{
	outError = nil;

	if (document == NULL || length == 0) {
		outError = MTLReflectionError(@"mslc returned an empty reflection document");
		return false;
	}

	NSData* data = [NSData dataWithBytes: document length: length];
	NSError* parseError = nil;

	// No NSJSONReadingAllowFragments: a reflection document that is not an
	// object is not a reflection, and the flag would let a bare array through.
	id root = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &parseError];

	if (root == nil) {
		outError = MTLReflectionError(@"mslc's reflection is not JSON: %@",
			[parseError localizedDescription]);
		return false;
	}

	if (![root isKindOfClass: [NSDictionary class]]) {
		outError = MTLReflectionError(@"mslc's reflection is not a JSON object");
		return false;
	}

	NSDictionary* object = (NSDictionary*)root;

	size_t version = 0;
	if (!MTLReadIndex([object objectForKey: @"reflection_version"], version) || version != 2) {
		outError = MTLReflectionError(@"mslc's reflection is version %lu, not the version 2 "
			@"document this reader knows how to read", (unsigned long)version);
		return false;
	}

	id entryPoints = [object objectForKey: @"entry_points"];
	if (![entryPoints isKindOfClass: [NSArray class]]) {
		outError = MTLReflectionError(@"mslc's reflection has no entry_points array");
		return false;
	}

	for (id entry in (NSArray*)entryPoints) {
		if (![entry isKindOfClass: [NSDictionary class]]) {
			outError = MTLReflectionError(@"mslc's reflection has an entry point that is not an object");
			return false;
		}

		NSDictionary* entryObject = (NSDictionary*)entry;
		Indium::FunctionReflection functionReflection;

		NSString* stage = nil;
		if (!MTLReadString(entryObject, @"stage", stage)) {
			outError = MTLReflectionError(@"mslc's reflection has no string stage");
			return false;
		}

		if (!MTLReadStageType(stage, functionReflection.functionType)) {
			outError = MTLReflectionError(@"mslc reported the stage '%@', which indium cannot run", stage);
			return false;
		}

		id bindings = [entryObject objectForKey: @"bindings"];
		if (![bindings isKindOfClass: [NSArray class]]) {
			outError = MTLReflectionError(@"mslc's reflection has no bindings array");
			return false;
		}

		if (!MTLReadEmbeddedSamplers([entryObject objectForKey: @"embedded_samplers"],
			functionReflection, outError) ||
			!MTLReadBindings((NSArray*)bindings, functionReflection, outError)) {
			return false;
		}

		NSString* entryPoint = nil;
		if (!MTLReadString(entryObject, @"name", entryPoint) || [entryPoint length] == 0) {
			outError = MTLReflectionError(@"mslc's reflection has no entry point name");
			return false;
		}

		outReflection.functions.emplace(
			std::string([entryPoint UTF8String]), std::move(functionReflection));
	}

	if (outReflection.functions.empty()) {
		outError = MTLReflectionError(@"mslc's reflection describes no entry point");
		return false;
	}

	return true;
}

#endif // DARLING_METAL_ENABLED
