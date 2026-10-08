#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>
#include <string.h>
static void fixtureCheck(BOOL ok, const char *why) { if(!ok) { fprintf(stderr,"FAIL %s\n",why); exit(1); } }
int main(int argc,char **argv) { @autoreleasepool {
 BOOL negative=argc==3 && strcmp(argv[2],"negative-green")==0;
 fixtureCheck(argc==2||negative,"shader path");
 NSString *source=[NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] encoding:NSUTF8StringEncoding error:nil];
 fixtureCheck(source!=nil,"source file");
 id<MTLDevice> device=MTLCreateSystemDefaultDevice(); fixtureCheck(device!=nil,"device");
 fprintf(stderr,"ENTER authored source API\n");
 NSError *error=nil; id<MTLLibrary> library=[device newLibraryWithSource:source options:nil error:&error];
 if(!library) { fprintf(stderr,"FAIL source: %s\n",[[error description]UTF8String]); return 2; }
 const char *names[]={"positionVertexShader","positionFragmentShader","texturePositionVertexShader","texturePositionFragmentShader"};
 id<MTLFunction> functions[4];
 for(unsigned i=0;i<4;i++) { functions[i]=[library newFunctionWithName:[NSString stringWithUTF8String:names[i]]]; fixtureCheck(functions[i]!=nil,"named function"); }
 float positions[]={-1,-1,0,1, 3,-1,0,1, -1,3,0,1};
 float identity[]={1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
 float coordinates[]={0,0, 2,0, 0,2};
 float white[]={1,1,1,1}, red[]={1,0,0,1};
 id<MTLBuffer> vertices=[device newBufferWithBytes:positions length:sizeof(positions) options:MTLResourceStorageModeShared];
 id<MTLBuffer> matrix=[device newBufferWithBytes:identity length:sizeof(identity) options:MTLResourceStorageModeShared];
 id<MTLBuffer> coords=[device newBufferWithBytes:coordinates length:sizeof(coordinates) options:MTLResourceStorageModeShared];
 id<MTLBuffer> colors[2]={[device newBufferWithBytes:red length:sizeof(red) options:MTLResourceStorageModeShared],[device newBufferWithBytes:white length:sizeof(white) options:MTLResourceStorageModeShared]};
 fixtureCheck(vertices&&matrix&&coords&&colors[0]&&colors[1],"buffers");
 MTLTextureDescriptor *sampleDesc=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:2 height:2 mipmapped:NO];
 sampleDesc.usage=MTLTextureUsageShaderRead; sampleDesc.storageMode=MTLStorageModeShared;
 id<MTLTexture> sample=[device newTextureWithDescriptor:sampleDesc];
 fixtureCheck(sample!=nil,"sample texture");
 unsigned char blue[]={0,0,255,255,0,0,255,255,0,0,255,255,0,0,255,255};
 [sample replaceRegion:MTLRegionMake2D(0,0,2,2) mipmapLevel:0 withBytes:blue bytesPerRow:8];
 id<MTLCommandQueue> queue=[device newCommandQueue]; fixtureCheck(queue!=nil,"queue");
 for(unsigned mode=0;mode<2;mode++) {
  MTLRenderPipelineDescriptor *pd=[MTLRenderPipelineDescriptor new];
  fixtureCheck(pd!=nil,"pipeline descriptor");
  pd.vertexFunction=functions[mode*2]; pd.fragmentFunction=functions[mode*2+1]; pd.rasterSampleCount=1;
  pd.colorAttachments[0].pixelFormat=MTLPixelFormatRGBA8Unorm;
  id<MTLRenderPipelineState> pipeline=[device newRenderPipelineStateWithDescriptor:pd error:&error];
  if(!pipeline) { fprintf(stderr,"FAIL pipeline %s\n",[[error description]UTF8String]); return 3; }
  MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:300 height:200 mipmapped:NO];
  td.usage=MTLTextureUsageRenderTarget; td.storageMode=MTLStorageModePrivate;
  id<MTLTexture> target=[device newTextureWithDescriptor:td]; fixtureCheck(target!=nil,"target");
  MTLRenderPassDescriptor *pass=[MTLRenderPassDescriptor renderPassDescriptor];
  pass.colorAttachments[0].texture=target; pass.colorAttachments[0].loadAction=MTLLoadActionClear;
  pass.colorAttachments[0].storeAction=MTLStoreActionStore; pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,1);
  id<MTLCommandBuffer> command=[queue commandBuffer];
  fixtureCheck(command!=nil,"render command");
  id<MTLRenderCommandEncoder> encoder=[command renderCommandEncoderWithDescriptor:pass];
  fixtureCheck(encoder!=nil,"render encoder");
  [encoder setRenderPipelineState:pipeline];
  [encoder setViewport:(MTLViewport){0,0,300,200,0,1}];
  [encoder setVertexBuffer:vertices offset:0 atIndex:0]; [encoder setVertexBuffer:matrix offset:0 atIndex:1];
  [encoder setFragmentBuffer:colors[mode] offset:0 atIndex:2];
  if(mode) { [encoder setVertexBuffer:coords offset:0 atIndex:3]; [encoder setFragmentTexture:sample atIndex:0]; }
  [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
  [encoder endEncoding]; [command commit]; [command waitUntilCompleted];
  id<MTLBuffer> output=[device newBufferWithLength:300*200*4 options:MTLResourceStorageModeShared];
  fixtureCheck(output!=nil,"output buffer");
  id<MTLCommandBuffer> copy=[queue commandBuffer]; fixtureCheck(copy!=nil,"copy command");
  id<MTLBlitCommandEncoder> blit=[copy blitCommandEncoder]; fixtureCheck(blit!=nil,"blit encoder");
  [blit copyFromTexture:target sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0) sourceSize:MTLSizeMake(300,200,1) toBuffer:output destinationOffset:0 destinationBytesPerRow:1200 destinationBytesPerImage:240000];
  [blit endEncoding]; [copy commit]; [copy waitUntilCompleted];
  const unsigned char *pixels=[output contents]; fixtureCheck(pixels!=NULL,"readback contents"); unsigned correct=0, wrong=0;
  for(unsigned i=0;i<60000;i++) { const unsigned char *p=pixels+i*4; correct+=p[0]==(mode?0:255)&&p[1]==0&&p[2]==(mode?255:0)&&p[3]==255; wrong+=p[0]==0&&p[1]==255&&p[2]==0&&p[3]==255; }
  printf("%s expected pixels %u/60000 negative-green %u\n",mode?"texture-blue":"position-red",correct,wrong); fflush(stdout);
  fixtureCheck((negative?wrong:correct)==60000 && (negative||wrong==0),"native exact pixels");
 }
 return 0;
} }
