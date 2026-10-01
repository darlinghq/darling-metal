// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLMSLReflection.h>
#import <Metal/stubs.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdarg.h>

#if DARLING_METAL_ENABLED

/*
 * mslc's reflection document, as of mslc master at 413bf6c, described in one
 * place because everything here is read off that shape and nothing else is
 * guessed at:
 *
 *   {
 *       "reflection_version": 2,
 *       "entry_points": [
 *           {
 *               "name": "add_arrays",
 *               "stage": "compute",
 *               "local_size": [1, 1, 1],
 *               "bindings": [
 *                   { "kind": "Buffer", "metal_index": 0,
 *                     "descriptor": { "set": 0, "binding": 0 },
 *                     "member": 0, "param_index": 0, "name": "inA" },
 *                   ...
 *               ]
 *           }
 *           ...
 *       ]
 *   }
 *
 * The stage vocabulary is "compute", "vertex" and "fragment". Note that a kernel
 * reports "compute", not "kernel": mslc's --stage option takes kernel/vertex/
 * fragment, but the stage it writes into the document is the SPIR-V execution
 * model, which is called compute. Reading "kernel" would never match a document
 * mslc actually produces.
 *
 * Version 2 is the shape mslc emits today. Version 1 was flat -- stage,
 * entry_point and bindings at the top level -- because a Metal source held a
 * single entry point, which is not true: newLibraryWithSource: is handed a file
 * carrying a vertex and a fragment function and compiles both. One document per
 * module with the entry points arrayed inside it is what that requires, so the
 * version went with it. The version is required to be exactly 2 rather than
 * parsed permissively, because a document whose shape is not known is a document
 * whose fields cannot be read, and reading it as if it were v1 would look for
 * keys that are not there and fail on the first one.
 *
 * Two things about it are worth stating rather than leaving to be discovered:
 *
 * The document is strict JSON. It was not: mslc wrote a comma after the last
 * binding, which a strict parser rejects, and cocotron's NSJSONSerialization was
 * lenient enough to accept it, so reading it depended on that leniency rather than
 * on the document being valid. mslc writes the separator before each entry instead
 * now (cristim/mslc#33), and every document checked here loads under a strict
 * parser. The leniency is no longer relied on, but nothing here depends on it
 * either way.
 *
 * Only buffers are described. Every entry mslc emits is "kind": "Buffer", from
 * the one place it writes reflection (src/sema.cpp, the buffer branch of the
 * parameter loop), and that string is a literal at that one site: there is no
 * code path in mslc that can emit a Texture, a Sampler or a VertexInput, and no
 * "embeddedSamplers" key in the document at all. A shader with a texture in it
 * therefore has no entry for that resource, and indium would build a descriptor
 * set layout it cannot satisfy. Reading a kind other than Buffer is refused
 * rather than mapped onto something, because the document carries no texture
 * access type and mapping it would mean guessing.
 *
 * That gap is currently behind an earlier one: mslc rejects a texture or sampler
 * parameter in its sema ("texture and sampler parameters are not lowered yet")
 * before it ever writes reflection, and its parser rejects the templated type
 * syntax real MSL uses. So fixing mslc's lowering alone would not make a textured
 * shader work here; the reflection has to grow at the same time.
 *
 * local_size is not read. indium takes the workgroup size from the module's
 * OpExecutionModeId LocalSizeId over SpecId 0, 1 and 2, which is what
 * dispatchThreads supplies, so a value here that disagreed with the module would
 * be a second answer to a question the module already answers.
 */

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
	if (![value isKindOfClass: [NSNumber class]]) {
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

static bool MTLReadBindingType(NSString* kind, Indium::BindingType& outType) {
	// Buffer is the only kind mslc emits, and it is the only one that can be read
	// correctly: the document carries no texture access type, so accepting a
	// Texture here would mean guessing between sampling and storage access from a
	// document that does not say, and guessing wrong binds a sampled texture as a
	// storage image. Adding a kind is a deliberate act that has to bring the
	// fields indium needs for it, at the point mslc starts emitting it.
	if ([kind isEqualToString: @"Buffer"]) {
		outType = Indium::BindingType::Buffer;
		return true;
	}

	return false;
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

		if (!MTLReadBindingType(kind, binding.type)) {
			outError = MTLReflectionError(
				@"mslc described a binding of kind '%@'; only Buffer bindings are "
				@"described yet, and this cannot be turned into a descriptor layout",
				kind);
			return false;
		}

		if (!MTLReadIndex([object objectForKey: @"metal_index"], binding.index)) {
			outError = MTLReflectionError(
				@"binding '%@' has no integer metal_index", kind);
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

		// textureAccessType and embeddedSamplerIndex keep their defaults: mslc
		// emits no embedded samplers, so embeddedSamplerIndex stays SIZE_MAX, and
		// a sampled texture is the only access type indium's defaults describe.
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

		if (!MTLReadBindings((NSArray*)bindings, functionReflection, outError)) {
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
