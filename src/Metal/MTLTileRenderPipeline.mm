// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLTileRenderPipeline.h>

@implementation MTLTileRenderPipelineColorAttachmentDescriptor

@synthesize pixelFormat = _pixelFormat;
@synthesize storeAction = _storeAction;
@synthesize storeActionOptions = _storeActionOptions;

- (id)copyWithZone: (NSZone*)zone
{
	MTLTileRenderPipelineColorAttachmentDescriptor* copy =
		[[MTLTileRenderPipelineColorAttachmentDescriptor allocWithZone: zone] init];

	copy.pixelFormat = _pixelFormat;
	copy.storeAction = _storeAction;
	copy.storeActionOptions = _storeActionOptions;

	return copy;
}

@end

// The concrete array behind -colorAttachments. It is not exported: Apple keeps
// the class that backs this protocol private too, and callers only ever hold it
// as id<MTLTileRenderPipelineColorAttachmentDescriptorArray>.
@interface MTLTileRenderPipelineColorAttachmentDescriptorArrayInternal
	: NSObject <MTLTileRenderPipelineColorAttachmentDescriptorArray>
{
	NSMutableArray* _attachments;
}
- (void)resizeToCount: (NSUInteger)count;
@end

@implementation MTLTileRenderPipelineColorAttachmentDescriptorArrayInternal

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_attachments = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_attachments release];
	[super dealloc];
}

- (NSUInteger)count
{
	return [_attachments count];
}

- (MTLTileRenderPipelineColorAttachmentDescriptor*)objectAtIndexedSubscript: (NSUInteger)index
{
	if (index >= [_attachments count]) {
		// Out of range is a caller error and NSArray's own answer for it is an
		// exception, so the same answer is given here rather than NULL, which a
		// caller would go on to dereference.
		[NSException raise: NSRangeException
		            format: @"index %lu is out of range for a colour attachment array of count %lu",
		           (unsigned long)index, (unsigned long)[_attachments count]];
	}

	return [_attachments objectAtIndex: index];
}

- (void)setObject: (MTLTileRenderPipelineColorAttachmentDescriptor*)object
    atIndexedSubscript: (NSUInteger)index
{
	if (object == nil) {
		[NSException raise: NSInvalidArgumentException
		            format: @"cannot store nil in a colour attachment array at index %lu",
		           (unsigned long)index];
	}

	if (index < [_attachments count]) {
		[_attachments replaceObjectAtIndex: index withObject: object];
	} else if (index == [_attachments count]) {
		[_attachments addObject: object];
	} else {
		[NSException raise: NSRangeException
		            format: @"index %lu is more than one past the end of a colour "
		                   @"attachment array of count %lu",
		           (unsigned long)index, (unsigned long)[_attachments count]];
	}
}

- (void)resizeToCount: (NSUInteger)count
{
	while ([_attachments count] > count) {
		[_attachments removeLastObject];
	}

	while ([_attachments count] < count) {
		[_attachments addObject: [[MTLTileRenderPipelineColorAttachmentDescriptor alloc] init]];
	}
}

@end

@implementation MTLTileRenderPipelineDescriptor

{
	MTLTileRenderPipelineColorAttachmentDescriptorArrayInternal* _colorAttachments;
}

@synthesize label = _label;
@synthesize tileFunction = _tileFunction;
@synthesize tileBuffers = _tileBuffers;
@synthesize threadgroupSizeMatchesTileSize = _threadgroupSizeMatchesTileSize;
@synthesize rasterSampleCount = _rasterSampleCount;
@synthesize maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
@synthesize requiredThreadsPerThreadgroup = _requiredThreadsPerThreadgroup;

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_colorAttachments =
			[[MTLTileRenderPipelineColorAttachmentDescriptorArrayInternal alloc] init];
		// One colour attachment is Apple's default, and a caller that goes
		// straight to colorAttachments[0] has to find an object there.
		[_colorAttachments resizeToCount: 1];
		[self reset];
	}
	return self;
}

- (void)dealloc
{
	[_colorAttachments release];
	[_label release];
	[_tileFunction release];
	[_tileBuffers release];
	[super dealloc];
}

- (id<MTLTileRenderPipelineColorAttachmentDescriptorArray>)colorAttachments
{
	return _colorAttachments;
}

- (void)reset
{
	[_label release];
	_label = nil;
	[_tileFunction release];
	_tileFunction = nil;
	[_tileBuffers release];
	_tileBuffers = nil;
	_threadgroupSizeMatchesTileSize = NO;
	_rasterSampleCount = 1;
	_maxTotalThreadsPerThreadgroup = 0;
	_requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 0);
	[_colorAttachments resizeToCount: 1];

	MTLTileRenderPipelineColorAttachmentDescriptor* first =
		[_colorAttachments objectAtIndexedSubscript: 0];
	first.pixelFormat = MTLPixelFormatInvalid;
	first.storeAction = MTLStoreActionDontCare;
	first.storeActionOptions = MTLStoreActionOptionNone;
}

- (id)copyWithZone: (NSZone*)zone
{
	MTLTileRenderPipelineDescriptor* copy = [[MTLTileRenderPipelineDescriptor allocWithZone: zone] init];

	// The copy starts with one attachment, so widen or narrow to the original's
	// count and then overwrite each element. Copying the array object itself
	// would alias it: mutating the copy's attachment 0 would mutate the
	// original's.
	MTLTileRenderPipelineColorAttachmentDescriptorArrayInternal* copyAttachments =
		(MTLTileRenderPipelineColorAttachmentDescriptorArrayInternal*)copy.colorAttachments;
	[copyAttachments resizeToCount: [_colorAttachments count]];

	for (NSUInteger i = 0; i < [_colorAttachments count]; i++) {
		[copyAttachments setObject:
			[[[_colorAttachments objectAtIndexedSubscript: i] copy] autorelease]
		 atIndexedSubscript: i];
	}

	copy.label = _label;
	copy.tileFunction = _tileFunction;
	copy.tileBuffers = _tileBuffers;
	copy.threadgroupSizeMatchesTileSize = _threadgroupSizeMatchesTileSize;
	copy.rasterSampleCount = _rasterSampleCount;
	copy.maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
	copy.requiredThreadsPerThreadgroup = _requiredThreadsPerThreadgroup;

	return copy;
}

@end
