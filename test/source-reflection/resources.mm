#import <Foundation/Foundation.h>
#import <Metal/MTLMSLReflection.h>
#include <cstdio>
#include <cstring>
int main() {
 NSAutoreleasePool* pool=[NSAutoreleasePool new];
 const char* bindings[]={
 "{\"kind\":\"Buffer\",\"metal_index\":2,\"descriptor\":{\"set\":1,\"binding\":0}}",
 "{\"kind\":\"Texture\",\"metal_index\":3,\"texture_access\":\"Sample\",\"descriptor\":{\"set\":1,\"binding\":1}}",
 "{\"kind\":\"Texture\",\"metal_index\":3,\"texture_access\":\"Write\",\"descriptor\":{\"set\":1,\"binding\":1}}",
 "{\"kind\":\"Sampler\",\"metal_index\":4,\"descriptor\":{\"set\":1,\"binding\":2}}"};
 int failures=0;
 for (int i=0;i<4;i++) {
  NSString* json=[NSString stringWithFormat:@"{\"reflection_version\":2,\"entry_points\":[{\"name\":\"f\",\"stage\":\"fragment\",\"bindings\":[%s]}]}",bindings[i]];
  Indium::LibraryReflection result; NSString* error=nil;
  bool ok=MTLReadMSLReflection([json UTF8String],strlen([json UTF8String]),result,error);
  bool match=ok && result.functions.at("f").bindings.size()==1;
  if(match) { const auto& f=result.functions.at("f"); const auto& b=f.bindings[0]; match=f.functionType==Indium::FunctionType::Fragment && b.index==(i==0?2:i==3?4:3) && b.internalIndex==(i==0?0:i==3?2:1) && b.type==(i==0?Indium::BindingType::Buffer:i==3?Indium::BindingType::Sampler:Indium::BindingType::Texture); }
  if(match && i==1) match=result.functions.at("f").bindings[0].textureAccessType==Indium::TextureAccessType::Sample;
  if(match && i==2) match=result.functions.at("f").bindings[0].textureAccessType==Indium::TextureAccessType::Write;
  printf("case%d %s%s%s\n",i,match?"PASS":"FAIL",error?": ":"",error?[error UTF8String]:"");
  failures+=!match;
 }
 const char* sampler="{\"s_address\":\"Repeat\",\"t_address\":\"ClampToEdge\",\"r_address\":\"ClampToZero\",\"mag_filter\":\"Linear\",\"min_filter\":\"Nearest\",\"mip_filter\":\"None\",\"normalized_coordinates\":true,\"compare_function\":\"Never\",\"anisotropy\":1,\"border_color\":\"TransparentBlack\",\"lod_min\":0,\"lod_max\":65504}";
 NSString* json=[NSString stringWithFormat:@"{\"reflection_version\":2,\"entry_points\":[{\"name\":\"f\",\"stage\":\"fragment\",\"bindings\":[{\"kind\":\"Sampler\",\"embedded_sampler\":0,\"descriptor\":{\"set\":1,\"binding\":2}}],\"embedded_samplers\":[%s]}]}",sampler];
 Indium::LibraryReflection result; NSString* error=nil;
 bool ok=MTLReadMSLReflection([json UTF8String],strlen([json UTF8String]),result,error);
 bool match=ok && result.functions.at("f").embeddedSamplers.size()==1 && result.functions.at("f").bindings[0].index==SIZE_MAX && result.functions.at("f").bindings[0].embeddedSamplerIndex==0;
 if(match) { const auto& state=result.functions.at("f").embeddedSamplers[0]; match=state.widthAddressMode==Indium::EmbeddedSamplerDescriptor::AddressMode::Repeat && state.magnificationFilter==Indium::EmbeddedSamplerDescriptor::Filter::Linear && state.lodMax==65504 && state.lodMin==0 && state.heightAddressMode==Indium::EmbeddedSamplerDescriptor::AddressMode::ClampToEdge && state.depthAddressMode==Indium::EmbeddedSamplerDescriptor::AddressMode::ClampToZero && state.minificationFilter==Indium::EmbeddedSamplerDescriptor::Filter::Nearest && state.mipmapFilter==Indium::EmbeddedSamplerDescriptor::MipFilter::None && state.usesNormalizedCoordinates && state.compareFunction==Indium::EmbeddedSamplerDescriptor::CompareFunction::Never && state.anisotropyLevel==1 && state.borderColor==Indium::EmbeddedSamplerDescriptor::BorderColor::TransparentBlack && result.functions.at("f").bindings[0].type==Indium::BindingType::Sampler && result.functions.at("f").bindings[0].internalIndex==2; }
 printf("embedded %s%s%s\n",match?"PASS":"FAIL",error?": ":"",error?[error UTF8String]:""); failures+=!match;
 const char* from[]={"Sample", "embedded_sampler\":0", "Repeat", "normalized_coordinates\":true", "lod_max\":65504", "embedded_samplers", "anisotropy\":1", "lod_min\":0", "set\":1", "embedded_sampler\":0"};
 const char* to[]={"Unknown", "embedded_sampler\":1", "Unknown", "normalized_coordinates\":7", "lod_max\":null", "unused", "anisotropy\":true", "lod_min\":65505", "set\":0", "embedded_sampler\":0,\"metal_index\":2"};
 for(int i=0;i<10;i++) {
  NSString* invalid=i==0?[NSString stringWithFormat:@"{\"reflection_version\":2,\"entry_points\":[{\"name\":\"f\",\"stage\":\"fragment\",\"bindings\":[%s]}]}",bindings[1]]:json;
  invalid=[invalid stringByReplacingOccurrencesOfString:[NSString stringWithUTF8String:from[i]] withString:[NSString stringWithUTF8String:to[i]]];
  Indium::LibraryReflection rejected; error=nil;
  bool rejects=!MTLReadMSLReflection([invalid UTF8String],strlen([invalid UTF8String]),rejected,error) && error!=nil;
  printf("invalid%d %s\n",i,rejects?"PASS":"FAIL"); failures+=!rejects;
 }
 [pool drain]; return failures?1:0;
}
