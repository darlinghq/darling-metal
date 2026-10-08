#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>

// A render pass descriptor's depth attachment must exist before it is assigned,
// like the color attachments: `descriptor.depthAttachment.texture = t` has to stick.
int main(void) {
 @autoreleasepool {
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  if (!device) { puts("FAIL no device"); return 2; }
  MTLTextureDescriptor *depthDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:8 height:8 mipmapped:NO];
  depthDescriptor.usage = MTLTextureUsageRenderTarget;
  depthDescriptor.storageMode = MTLStorageModePrivate;
  id<MTLTexture> depth = [device newTextureWithDescriptor:depthDescriptor];
  MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
  pass.depthAttachment.texture = depth;
  pass.depthAttachment.clearDepth = 0.5;
  pass.depthAttachment.loadAction = MTLLoadActionClear;
  int ok = pass.depthAttachment != nil && pass.depthAttachment.texture == depth && pass.depthAttachment.clearDepth == 0.5 && pass.depthAttachment.loadAction == MTLLoadActionClear;
  printf("depth attachment texture %s clearDepth %.2f loadAction %lu\n", pass.depthAttachment.texture == depth ? "kept" : "LOST", pass.depthAttachment.clearDepth, (unsigned long)pass.depthAttachment.loadAction);
  puts(ok ? "PASS" : "FAIL");
  return !ok;
 }
}
