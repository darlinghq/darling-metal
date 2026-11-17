// Copyright (C) 2026 Lubos Dolezel

#import <Metal/MTLParallelRenderCommandEncoderInternal.h>
#import <Metal/MTLRenderCommandEncoderInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>

@implementation MTLParallelRenderCommandEncoderInternal

#if DARLING_METAL_ENABLED

{
	std::shared_ptr<Indium::ParallelRenderCommandEncoder> _encoder;
}

@synthesize device = _device;
@synthesize label = _label;

- (instancetype)initWithEncoder: (std::shared_ptr<Indium::ParallelRenderCommandEncoder>)encoder
                         device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_encoder = encoder;
		_device = [device retain];
	}
	return self;
}

- (void)dealloc
{
	[_device release];
	[_label release];
	[super dealloc];
}

- (void)endEncoding
{
	_encoder->endEncoding();
}

- (id<MTLRenderCommandEncoder>)renderCommandEncoder
{
	auto encoder = _encoder->renderCommandEncoder();
	if (!encoder) {
		return nil;
	}
	return [[[MTLRenderCommandEncoderInternal alloc] initWithEncoder: encoder device: _device] autorelease];
}

- (void)setColorStoreAction: (MTLStoreAction)storeAction
                    atIndex: (NSUInteger)colorAttachmentIndex
{
	_encoder->setColorStoreAction(static_cast<Indium::StoreAction>(storeAction), colorAttachmentIndex);
}

- (void)setDepthStoreAction: (MTLStoreAction)storeAction
{
	_encoder->setDepthStoreAction(static_cast<Indium::StoreAction>(storeAction));
}

- (void)setStencilStoreAction: (MTLStoreAction)storeAction
{
	_encoder->setStencilStoreAction(static_cast<Indium::StoreAction>(storeAction));
}

- (void)setColorStoreActionOptions: (MTLStoreActionOptions)storeActionOptions
                           atIndex: (NSUInteger)colorAttachmentIndex
{
	_encoder->setColorStoreActionOptions(static_cast<Indium::StoreActionOptions>(storeActionOptions), colorAttachmentIndex);
}

- (void)setDepthStoreActionOptions: (MTLStoreActionOptions)storeActionOptions
{
	_encoder->setDepthStoreActionOptions(static_cast<Indium::StoreActionOptions>(storeActionOptions));
}

- (void)setStencilStoreActionOptions: (MTLStoreActionOptions)storeActionOptions
{
	_encoder->setStencilStoreActionOptions(static_cast<Indium::StoreActionOptions>(storeActionOptions));
}

#else

@dynamic device;
@dynamic label;

MTL_UNSUPPORTED_CLASS

#endif

@end
