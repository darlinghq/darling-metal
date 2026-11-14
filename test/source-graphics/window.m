#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <QuartzCore/CAMetalDrawable.h>
#include <stdio.h>
static BOOL blue;
static void fixtureCheck(BOOL ok, const char* reason) { if(!ok) { fprintf(stderr,"FAIL %s\n",reason); exit(1); } }
@interface SourceView : NSView @end
@implementation SourceView
- (CALayer*)makeBackingLayer { return [CAMetalLayer layer]; }
- (BOOL)wantsUpdateLayer { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)keyDown:(NSEvent*)event {
 if([event.characters isEqualToString:@"b"]) { blue=YES; puts("INPUT texture-blue"); fflush(stdout); }
}
@end
@interface SourceDriver : NSObject {
 CAMetalLayer* _layer;
 id<MTLCommandQueue> _queue;
 id<MTLRenderPipelineState> _pipeline[2];
 id<MTLBuffer> _vertices, _matrix, _coords, _colors[2];
 id<MTLTexture> _sample;
 unsigned _frames;
}
- (id)initWithLayer:(CAMetalLayer*)layer source:(NSString*)source;
- (void)frame:(NSTimer*)timer;
@end
@implementation SourceDriver
- (id)initWithLayer:(CAMetalLayer*)layer source:(NSString*)source {
 if((self=[super init])) {
  _layer=[layer retain]; id<MTLDevice> device=layer.device;
  NSError* error=nil; id<MTLLibrary> library=[device newLibraryWithSource:source options:nil error:&error];
  if(!library) { fprintf(stderr,"FAIL source %s\n",[[error description]UTF8String]); exit(2); }
  const char* names[]={"positionVertexShader","positionFragmentShader","texturePositionVertexShader","texturePositionFragmentShader"};
  for(unsigned mode=0;mode<2;mode++) {
   MTLRenderPipelineDescriptor* pd=[MTLRenderPipelineDescriptor new];
   pd.vertexFunction=[library newFunctionWithName:[NSString stringWithUTF8String:names[mode*2]]];
   pd.fragmentFunction=[library newFunctionWithName:[NSString stringWithUTF8String:names[mode*2+1]]];
   fixtureCheck(pd.vertexFunction&&pd.fragmentFunction,"functions");
   pd.colorAttachments[0].pixelFormat=layer.pixelFormat; pd.rasterSampleCount=1;
   _pipeline[mode]=[device newRenderPipelineStateWithDescriptor:pd error:&error];
   fixtureCheck(_pipeline[mode]!=nil,"pipeline"); [pd release];
  }
  [library release];
  float positions[]={-1,-1,0,1,3,-1,0,1,-1,3,0,1};
  float identity[]={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};
  float coordinates[]={0,0,2,0,0,2}, red[]={1,0,0,1}, white[]={1,1,1,1};
  _vertices=[device newBufferWithBytes:positions length:sizeof(positions) options:MTLResourceStorageModeShared];
  _matrix=[device newBufferWithBytes:identity length:sizeof(identity) options:MTLResourceStorageModeShared];
  _coords=[device newBufferWithBytes:coordinates length:sizeof(coordinates) options:MTLResourceStorageModeShared];
  _colors[0]=[device newBufferWithBytes:red length:sizeof(red) options:MTLResourceStorageModeShared];
  _colors[1]=[device newBufferWithBytes:white length:sizeof(white) options:MTLResourceStorageModeShared];
  fixtureCheck(_vertices&&_matrix&&_coords&&_colors[0]&&_colors[1],"buffers");
  MTLTextureDescriptor* td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:2 height:2 mipmapped:NO];
  td.usage=MTLTextureUsageShaderRead; td.storageMode=MTLStorageModeShared;
  _sample=[device newTextureWithDescriptor:td]; fixtureCheck(_sample!=nil,"sample");
  unsigned char pixels[]={0,0,255,255,0,0,255,255,0,0,255,255,0,0,255,255};
  [_sample replaceRegion:MTLRegionMake2D(0,0,2,2) mipmapLevel:0 withBytes:pixels bytesPerRow:8];
  _queue=[device newCommandQueue]; fixtureCheck(_queue!=nil,"queue");
 }
 return self;
}
- (void)frame:(NSTimer*)timer { @autoreleasepool {
 id<CAMetalDrawable> drawable=[_layer nextDrawable]; fixtureCheck(drawable!=nil,"drawable");
 MTLRenderPassDescriptor* pass=[MTLRenderPassDescriptor renderPassDescriptor];
 pass.colorAttachments[0].texture=drawable.texture;
 pass.colorAttachments[0].loadAction=MTLLoadActionClear; pass.colorAttachments[0].storeAction=MTLStoreActionStore;
 pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,1);
 id<MTLCommandBuffer> command=[_queue commandBuffer]; fixtureCheck(command!=nil,"command");
 id<MTLRenderCommandEncoder> encoder=[command renderCommandEncoderWithDescriptor:pass]; fixtureCheck(encoder!=nil,"encoder");
 unsigned mode=blue?1:0;
 [encoder setRenderPipelineState:_pipeline[mode]];
 [encoder setViewport:(MTLViewport){0,0,300,200,0,1}];
 [encoder setVertexBuffer:_vertices offset:0 atIndex:0]; [encoder setVertexBuffer:_matrix offset:0 atIndex:1];
 [encoder setFragmentBuffer:_colors[mode] offset:0 atIndex:2];
 if(mode) { [encoder setVertexBuffer:_coords offset:0 atIndex:3]; [encoder setFragmentTexture:_sample atIndex:0]; }
 [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
 [encoder endEncoding]; [command presentDrawable:drawable]; [command commit]; [command waitUntilCompleted];
 if(++_frames==3) { puts("CAPTURE_READY position-red"); fflush(stdout); }
} }
@end
int main(int argc,char** argv) { @autoreleasepool {
 fixtureCheck(argc==2,"source path");
 NSString* source=[NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] encoding:NSUTF8StringEncoding error:nil];
 fixtureCheck(source!=nil,"source"); [NSApplication sharedApplication];
 NSWindow* window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,300,200) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
 SourceView* view=[[SourceView alloc] initWithFrame:NSMakeRect(0,0,300,200)]; view.wantsLayer=YES;
 [window setContentView:view]; CAMetalLayer* layer=(CAMetalLayer*)view.layer;
 layer.device=MTLCreateSystemDefaultDevice(); layer.drawableSize=CGSizeMake(300,200); fixtureCheck(layer.device!=nil,"device");
 SourceDriver* driver=[[SourceDriver alloc] initWithLayer:layer source:source]; fixtureCheck(driver!=nil,"driver");
 [window makeFirstResponder:view]; [window makeKeyAndOrderFront:nil];
 [NSTimer scheduledTimerWithTimeInterval:0.2 target:driver selector:@selector(frame:) userInfo:nil repeats:YES];
 [NSApp run]; return 0;
} }
