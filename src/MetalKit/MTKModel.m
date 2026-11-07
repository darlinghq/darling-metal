// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <MetalKit/MTKModel.h>
#import <Metal/stubs.h>

// Everything in this file bridges ModelIO to Metal, and Darling's ModelIO is a set of forwarding
// stubs holding no vertex, index or descriptor data. There is nothing to convert, so these classes
// exist for linkage only and refuse any actual use. The declared methods are deliberately left
// unimplemented so that the forwarding below catches them too.
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation MTKMeshBufferAllocator

MTL_UNSUPPORTED_CLASS

@end

@implementation MTKMesh

MTL_UNSUPPORTED_CLASS

@end

MDLVertexDescriptor* MTKModelIOVertexDescriptorFromMetal(MTLVertexDescriptor* metalDescriptor)
{
	NSLog(@"MTKModelIOVertexDescriptorFromMetal: ModelIO is not implemented in Darling, so there is no descriptor to return");
	abort();
}
