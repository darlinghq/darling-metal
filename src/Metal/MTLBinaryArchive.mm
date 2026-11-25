// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLBinaryArchiveInternal.h>
#import <Metal/MTLComputePipeline.h>
#import <Metal/MTLRenderPipeline.h>
#import <Metal/MTLIndiumErrors.h>
#import <Metal/stubs.h>

#if DARLING_METAL_ENABLED
#import <Metal/MTLLibraryInternal.h>
#import <Metal/MTLTypesInternal.h>
#endif

NSErrorDomain const MTLBinaryArchiveDomain = @"MTLBinaryArchiveDomain";

#if __LP64__


@implementation MTLBinaryArchiveDescriptor

@synthesize url = _url;

- (void)dealloc
{
	[_url release];
	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLBinaryArchiveDescriptor* copy = [[MTLBinaryArchiveDescriptor allocWithZone: zone] init];

	copy.url = _url;

	return copy;
}

@end

// An archive file is a binary property list:
//
//   Format     "org.darlinghq.Metal.BinaryArchive"
//   Version    1
//   Functions  an array of the functions' archive keys (-[MTLFunctionInternal archiveKey]): 32 bytes of data each
static NSString* const MTLBinaryArchiveFormat = @"org.darlinghq.Metal.BinaryArchive";
static const NSInteger MTLBinaryArchiveVersion = 1;
static const NSUInteger MTLBinaryArchiveKeyLength = 32;

static NSError* MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveError code, NSString* description, NSError* underlying)
{
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject: description forKey: NSLocalizedDescriptionKey];
	if (underlying) {
		userInfo[NSUnderlyingErrorKey] = underlying;
	}
	return [NSError errorWithDomain: MTLBinaryArchiveDomain code: code userInfo: userInfo];
}

@implementation MTLBinaryArchiveInternal

#if DARLING_METAL_ENABLED

{
	NSMutableSet<NSData*>* _functions;
}

@synthesize device = _device;
@synthesize label = _label;

// What identifies `function` in an archive; nil for nil or an object that is not a function of this framework
static NSData* archiveKey(id<MTLFunction> function)
{
	static const Class functionClass = [MTLFunctionInternal class];
	if (!MTLObjectIsInstanceOf(function, functionClass)) {
		return nil;
	}
	return ((MTLFunctionInternal*)function).archiveKey;
}

// The archive key of a descriptor's function for a pipeline stage; nil, with an error, when the function is
// missing or of another type
static NSData* stageKey(id<MTLFunction> function, MTLFunctionType type, NSString* stage, NSError** error)
{
	NSData* key = archiveKey(function);
	if (key == nil || function.functionType != type) {
		if (error) {
			*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorUnexpectedElement, [NSString stringWithFormat: @"The descriptor has no %@ function", stage], nil);
		}
		return nil;
	}
	return key;
}

// The keys of the archive file at `url`, or nil when it is not one
static NSSet<NSData*>* readArchive(NSURL* url, NSError** error)
{
	if (!url.isFileURL) {
		*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInvalidFile, @"The archive URL is not a file URL", nil);
		return nil;
	}
	NSError* readError = nil;
	NSData* data = [NSData dataWithContentsOfURL: url options: 0 error: &readError];
	if (data == nil) {
		*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInvalidFile, @"The archive file could not be read", readError);
		return nil;
	}

	NSDictionary* archive = [NSPropertyListSerialization propertyListWithData: data options: NSPropertyListImmutable format: NULL error: NULL];
	if (![archive isKindOfClass: [NSDictionary class]] || ![archive[@"Format"] isEqual: MTLBinaryArchiveFormat]) {
		*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInvalidFile, @"The file is not a binary archive", nil);
		return nil;
	}
	if (![archive[@"Version"] isEqual: @(MTLBinaryArchiveVersion)]) {
		*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInvalidFile, @"The binary archive has an unsupported version", nil);
		return nil;
	}
	NSArray* functions = archive[@"Functions"];
	if (![functions isKindOfClass: [NSArray class]]) {
		*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInvalidFile, @"The binary archive has no function list", nil);
		return nil;
	}
	for (id function in functions) {
		if (![function isKindOfClass: [NSData class]] || [function length] != MTLBinaryArchiveKeyLength) {
			*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInvalidFile, @"The binary archive has an invalid function entry", nil);
			return nil;
		}
	}
	return [NSSet setWithArray: functions];
}

- (instancetype)initWithDevice: (id<MTLDevice>)device
                           url: (NSURL*)url
                         error: (NSError**)error
{
	if (error) {
		*error = nil;
	}
	self = [super init];
	if (self != nil) {
		_device = [device retain];
		_functions = [NSMutableSet new];
		if (url != nil) {
			NSError* readError = nil;
			NSSet<NSData*>* functions = readArchive(url, &readError);
			if (functions == nil) {
				if (error) {
					*error = readError;
				}
				[self release];
				return nil;
			}
			[_functions unionSet: functions];
		}
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[_functions release];
	[super dealloc];
}

- (BOOL)containsFunction: (id<MTLFunction>)function
{
	NSData* key = archiveKey(function);
	@synchronized (self) {
		return key != nil && [_functions containsObject: key];
	}
}

- (BOOL)addComputePipelineFunctionsWithDescriptor: (MTLComputePipelineDescriptor*)descriptor
                                            error: (NSError**)error
{
	if (error) {
		*error = nil;
	}
	NSData* key = stageKey(descriptor.computeFunction, MTLFunctionTypeKernel, @"kernel", error);
	if (key == nil) {
		return NO;
	}
	@synchronized (self) {
		[_functions addObject: key];
	}
	return YES;
}

- (BOOL)addRenderPipelineFunctionsWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                           error: (NSError**)error
{
	if (error) {
		*error = nil;
	}
	NSData* vertexKey = stageKey(descriptor.vertexFunction, MTLFunctionTypeVertex, @"vertex", error);
	if (vertexKey == nil) {
		return NO;
	}
	// a render pipeline may have no fragment function
	NSData* fragmentKey = nil;
	if (descriptor.fragmentFunction != nil) {
		fragmentKey = stageKey(descriptor.fragmentFunction, MTLFunctionTypeFragment, @"fragment", error);
		if (fragmentKey == nil) {
			return NO;
		}
	}
	@synchronized (self) {
		[_functions addObject: vertexKey];
		if (fragmentKey != nil) {
			[_functions addObject: fragmentKey];
		}
	}
	return YES;
}

- (BOOL)serializeToURL: (NSURL*)url
                 error: (NSError**)error
{
	if (error) {
		*error = nil;
	}
	if (!url.isFileURL) {
		if (error) {
			*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInvalidFile, @"The archive URL is not a file URL", nil);
		}
		return NO;
	}

	NSArray<NSData*>* functions;
	@synchronized (self) {
		functions = [_functions allObjects];
	}
	NSDictionary* archive = @{
		@"Format": MTLBinaryArchiveFormat,
		@"Version": @(MTLBinaryArchiveVersion),
		@"Functions": functions,
	};
	NSError* writeError = nil;
	NSData* data = [NSPropertyListSerialization dataWithPropertyList: archive format: NSPropertyListBinaryFormat_v1_0 options: 0 error: &writeError];
	if (data == nil) {
		if (error) {
			*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInternalError, @"The archive could not be encoded", writeError);
		}
		return NO;
	}
	if (![data writeToURL: url options: NSDataWritingAtomic error: &writeError]) {
		if (error) {
			*error = MTLBinaryArchiveErrorWithCode(MTLBinaryArchiveErrorInvalidFile, @"The archive file could not be written", writeError);
		}
		return NO;
	}
	return YES;
}

#else

@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end

#if DARLING_METAL_ENABLED

BOOL MTLBinaryArchivesContainFunctions(NSArray<id<MTLBinaryArchive>>* archives, NSArray<id<MTLFunction>>* functions, NSError** error)
{
	static const Class archiveClass = [MTLBinaryArchiveInternal class];
	// QUIRK: with no binary archives (nil or empty), MTLPipelineOptionFailOnBinaryArchiveMiss has no effect and
	// the pipeline is compiled. The documentation of the option does not say what happens without archives.
	// Evidence: black-box observation on macOS 27 (Apple M1), for compute pipelines made from a descriptor with
	// nil or empty binaryArchives and from a function alone (tier 2). Test: test/guest/binary_archive.m, "with
	// no archives to look in".
	if (archives.count == 0) {
		return YES;
	}
	for (id<MTLFunction> function in functions) {
		BOOL found = NO;
		for (id<MTLBinaryArchive> archive in archives) {
			if (MTLObjectIsInstanceOf(archive, archiveClass) && [(MTLBinaryArchiveInternal*)archive containsFunction: function]) {
				found = YES;
				break;
			}
		}
		if (!found) {
			MTLSetError(error, MTLLibraryErrorFunctionNotFound, [NSString stringWithFormat: @"Function '%@' is not in the pipeline's binary archives", function.name]);
			return NO;
		}
	}
	return YES;
}

#endif

#endif // __LP64__
