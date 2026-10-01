// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLIndirectCommandBuffer.h>

#if __LP64__


@implementation MTLIndirectCommandBufferDescriptor

@synthesize inheritPipelineState = _inheritPipelineState;
@synthesize inheritBuffers = _inheritBuffers;
@synthesize maxVertexBufferBindCount = _maxVertexBufferBindCount;
@synthesize maxFragmentBufferBindCount = _maxFragmentBufferBindCount;
@synthesize maxKernelBufferBindCount = _maxKernelBufferBindCount;
@synthesize commandTypes = _commandTypes;

- (id)copyWithZone: (NSZone*)zone
{
	MTLIndirectCommandBufferDescriptor* copy =
		[[MTLIndirectCommandBufferDescriptor allocWithZone: zone] init];

	copy.inheritPipelineState = _inheritPipelineState;
	copy.inheritBuffers = _inheritBuffers;
	copy.maxVertexBufferBindCount = _maxVertexBufferBindCount;
	copy.maxFragmentBufferBindCount = _maxFragmentBufferBindCount;
	copy.maxKernelBufferBindCount = _maxKernelBufferBindCount;
	copy.commandTypes = _commandTypes;

	return copy;
}

@end

#endif // __LP64__
