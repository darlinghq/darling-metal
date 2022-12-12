/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Metal/MTLComputePipelineInternal.h>
#import <Metal/MTLPipelineInternal.h>
#import <Metal/MTLLibraryInternal.h>
#import <Metal/MTLTypesInternal.h>
#import <Metal/MTLDevice.h>
#import <Metal/stubs.h>

@implementation MTLComputePipelineDescriptor

#if __OBJC2__

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_computeFunction = nil;
		_threadGroupSizeIsMultipleOfThreadExecutionWidth = NO;
		_maxTotalThreadsPerThreadgroup = 0; // this indicates to Indium that we haven't changed it from the default; TODO: check what the actual default is
		_maxCallStackDepth = 1;
		_stageInputDescriptor = nil;
		_buffers = [MTLPipelineBufferDescriptorArray new];
		_supportIndirectCommandBuffers = NO; // TODO: check what the actual default is
		_preloadedLibraries = [NSArray new];
		_linkedFunctions = nil;
		_supportAddingBinaryFunctions = NO; // TODO: check what the actual default is
		_binaryArchives = nil;
	}
	return self;
}

- (void)dealloc
{
	[_computeFunction release];
	[_stageInputDescriptor release];
	[_buffers release];
	[_preloadedLibraries release];
	[_linkedFunctions release];
	[_binaryArchives release];

	[super dealloc];
}

- (id)copyWithZone: (NSZone*)zone
{
	// TODO: check the actual copy behavior of the official Metal class.
	//       for now, we just use a reasonable assumption.
	MTLComputePipelineDescriptor* copy = [MTLComputePipelineDescriptor new];

	copy.computeFunction = self.computeFunction;
	copy.threadGroupSizeIsMultipleOfThreadExecutionWidth = self.threadGroupSizeIsMultipleOfThreadExecutionWidth;
	copy.maxTotalThreadsPerThreadgroup = self.maxTotalThreadsPerThreadgroup;
	copy.maxCallStackDepth = self.maxCallStackDepth;
	copy.stageInputDescriptor = self.stageInputDescriptor;
	copy->_buffers = [_buffers copy];
	copy.supportIndirectCommandBuffers = self.supportIndirectCommandBuffers;
	copy.preloadedLibraries = self.preloadedLibraries;
	copy.linkedFunctions = self.linkedFunctions;
	copy.supportAddingBinaryFunctions = self.supportAddingBinaryFunctions;
	copy.binaryArchives = self.binaryArchives;

	return copy;
}

- (NSArray<id<MTLDynamicLibrary>>*)insertLibraries
{
	return self.preloadedLibraries;
}

- (void)setInsertLibraries: (NSArray<id<MTLDynamicLibrary>>*)insertLibraries
{
	self.preloadedLibraries = insertLibraries;
}

- (void)reset
{
	self.computeFunction = nil;
	self.threadGroupSizeIsMultipleOfThreadExecutionWidth = NO;
	self.maxTotalThreadsPerThreadgroup = 0; // TODO: check what the actual default is
	self.maxCallStackDepth = 1;
	self.stageInputDescriptor = nil;
	[_buffers release];
	_buffers = [MTLPipelineBufferDescriptorArray new];
	self.supportIndirectCommandBuffers = NO; // TODO: check what the actual default is
	self.preloadedLibraries = [NSArray new];
	self.linkedFunctions = nil;
	self.supportAddingBinaryFunctions = NO; // TODO: check what the actual default is
	self.binaryArchives = nil;
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end

@implementation MTLComputePipelineDescriptor (Internal)

#if __OBJC2__

- (Indium::ComputePipelineDescriptor)asIndiumDescriptor
{
	return Indium::ComputePipelineDescriptor {
		((MTLFunctionInternal*)_computeFunction).function,
		static_cast<bool>(_threadGroupSizeIsMultipleOfThreadExecutionWidth),
		_maxTotalThreadsPerThreadgroup,
		_maxCallStackDepth,
		std::nullopt, // TODO
		{}, // TODO
		static_cast<bool>(_supportIndirectCommandBuffers),
		{}, // TODO
		nullptr, // TODO
		static_cast<bool>(_supportAddingBinaryFunctions),
		{}, // TODO
	};
}

#endif

@end

@implementation MTLComputePipelineStateInternal

#if __OBJC2__

@synthesize device = _device;
@synthesize state = _pso;

- (instancetype)initWithState: (std::shared_ptr<Indium::ComputePipelineState>)state
                       device: (id<MTLDevice>)device
{
	self = [super init];
	if (self != nil) {
		_pso = state;
		_device = [device retain];
	}
	return self;
}

- (void)dealloc
{
	[_device release];

	[super dealloc];
}

- (NSUInteger)imageblockMemoryLengthForDimensions: (MTLSize)imageblockDimensions
{
	return _pso->imageblockMemoryLength(MTLSizeToIndium(imageblockDimensions));
}

- (id<MTLFunctionHandle>)functionHandleWithFunction: (id<MTLFunction>)function
{
	// TODO
	return nil;
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithAdditionalBinaryFunctions: (NSArray<id<MTLFunction>>*)functions 
                                                                              error: (NSError**)error
{
	// TODO
	return nil;
}

- (id<MTLVisibleFunctionTable>)newVisibleFunctionTableWithDescriptor: (MTLVisibleFunctionTableDescriptor*)descriptor
{
	// TODO
	return nil;
}

- (id<MTLIntersectionFunctionTable>)newIntersectionFunctionTableWithDescriptor: (MTLIntersectionFunctionTableDescriptor*)descriptor
{
	// TODO
	return nil;
}

- (NSUInteger)maxTotalThreadsPerThreadgroup
{
	return _pso->maxTotalThreadsPerThreadgroup();
}

- (NSUInteger)threadExecutionWidth
{
	return _pso->threadExecutionWidth();
}

- (NSUInteger)staticThreadgroupMemoryLength
{
	return _pso->staticThreadgroupMemoryLength();
}

- (BOOL)supportIndirectCommandBuffers
{
	return _pso->supportIndirectCommandBuffers();
}

#else

MTL_UNSUPPORTED_CLASS

#endif

@end
