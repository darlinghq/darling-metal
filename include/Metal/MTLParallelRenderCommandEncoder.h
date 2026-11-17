// Copyright (C) 2026 Lubos Dolezel

#ifndef _METAL_MTLPARALLELRENDERCOMMANDENCODER_H_
#define _METAL_MTLPARALLELRENDERCOMMANDENCODER_H_

#import <Metal/MTLDefines.h>
#import <Metal/MTLCommandEncoder.h>
#import <Metal/MTLRenderCommandEncoder.h>

METAL_DECLARATIONS_BEGIN

// One render pass that several render command encoders record, typically each on its own thread. The commands of the
// encoders run in the order the encoders were created from this one, whatever order they were used or ended in. The
// pass's load actions apply once, at its start, and its store actions once, at its end.
@protocol MTLParallelRenderCommandEncoder <MTLCommandEncoder>

// A new encoder for the pass, whose commands come after those of the encoders made before it. Every encoder has to
// be ended before this one is.
- (nullable id<MTLRenderCommandEncoder>)renderCommandEncoder;

- (void)setColorStoreAction: (MTLStoreAction)storeAction
                    atIndex: (NSUInteger)colorAttachmentIndex;
- (void)setDepthStoreAction: (MTLStoreAction)storeAction;
- (void)setStencilStoreAction: (MTLStoreAction)storeAction;

- (void)setColorStoreActionOptions: (MTLStoreActionOptions)storeActionOptions
                           atIndex: (NSUInteger)colorAttachmentIndex;
- (void)setDepthStoreActionOptions: (MTLStoreActionOptions)storeActionOptions;
- (void)setStencilStoreActionOptions: (MTLStoreActionOptions)storeActionOptions;

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLPARALLELRENDERCOMMANDENCODER_H_
