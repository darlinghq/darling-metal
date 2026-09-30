# SPDX-FileCopyrightText: 2026 Darling Developers
# SPDX-License-Identifier: MPL-2.0

project(metal)

remove_sdk_framework(Metal)
remove_sdk_framework(MetalKit)
remove_sdk_framework(MetalPerformanceShaders)

if (BUILD_METAL)
	add_subdirectory(deps/indium)

	#
	# mslc, an MSL to Vulkan SPIR-V compiler, linked into Metal.framework so that
	# -[MTLDevice newLibraryWithSource:options:error:] has a front end to call.
	#
	# mslc's own CMakeLists.txt is deliberately not used. It builds a CLI driver
	# and a corpus runner that fork/exec spirv-val, neither of which belongs in a
	# guest address space with no host exec path, and mslc is a repository other
	# people work on, so a target appearing there must not become a reason this
	# one stops building. The six sources below are the whole library; main.cpp is
	# the driver.
	#
	# The public surface is a C ABI declared in deps/mslc/include/mslc/mslc.h, which
	# is what Metal.framework includes. No C++ of mslc's is visible past it.
	#
	set(DYLIB_INSTALL_NAME "/usr/lib/darling/libmslc.dylib")
	add_darling_library(mslc
		deps/mslc/src/lexer.cpp
		deps/mslc/src/ast.cpp
		deps/mslc/src/parser.cpp
		deps/mslc/src/sema.cpp
		deps/mslc/src/spirv.cpp
		deps/mslc/src/mslc.cpp
	)
	make_fat(mslc)

	install(TARGETS mslc DESTINATION libexec/darling/usr/lib/darling)

	target_include_directories(mslc PUBLIC
		deps/mslc/include
	)

	target_include_directories(mslc PRIVATE
		deps/mslc/src
	)

	set_target_properties(mslc PROPERTIES
		CXX_STANDARD 17
		CXX_STANDARD_REQUIRED ON
		CXX_EXTENSIONS OFF
	)

	target_link_libraries(mslc PRIVATE
		cxx
		system
	)
endif()

#
# Metal
#

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(Metal
	VERSION ${FRAMEWORK_VERSION}
	HEADER "include/Metal"
)

if (BUILD_METAL)
	set(METAL_LINK_INDIUM indium)
	set(METAL_LINK_MSLC mslc)
else()
	set(METAL_LINK_INDIUM "")
	set(METAL_LINK_MSLC "")
endif()

add_framework(Metal
	# Metal is not supported in 32-bit apps, but it does still link successfully into such apps.
	# thus, we have to provide a 32-bit build of the framework, but it doesn't have to provide any
	# functionality. so e.g. we can use modern objc features like non-fragile classes.
	FAT
	CURRENT_VERSION
	VERSION ${FRAMEWORK_VERSION}

	SOURCES
		src/Metal/MTLAccelerationStructure.mm
		src/Metal/MTLAccelerationStructureDescriptor.mm
		src/Metal/MTLAccelerationStructureGeometryDescriptor.mm
		src/Metal/MTLArgument.mm
		src/Metal/MTLArgumentDescriptor.mm
		src/Metal/MTLBinaryArchive.mm
		src/Metal/MTLBlitCommandEncoder.mm
		src/Metal/MTLBuffer.mm
		src/Metal/MTLCaptureManager.mm
		src/Metal/MTLCommandBuffer.mm
		src/Metal/MTLCommandBufferDescriptor.mm
		src/Metal/MTLCommandQueue.mm
		src/Metal/MTLCompileOptions.mm
		src/Metal/MTLComputeCommandEncoder.mm
		src/Metal/MTLComputePipeline.mm
		src/Metal/MTLCounterSampleBuffer.mm
		src/Metal/MTLDepthStencilDescriptor.mm
		src/Metal/MTLDevice.mm
		src/Metal/MTLDrawable.mm
		src/Metal/MTLFunctionConstantValues.mm
		src/Metal/MTLHeap.mm
		src/Metal/MTLIndirectCommandBuffer.mm
		src/Metal/MTLIntersectionFunctionTable.mm
		src/Metal/MTLIOSurfaceCopy.mm
		src/Metal/MTLLibrary.mm
		src/Metal/MTLLinkedFunctions.mm
		src/Metal/MTLMSLReflection.mm
		src/Metal/MTLPipeline.mm
		src/Metal/MTLRenderCommandEncoder.mm
		src/Metal/MTLRenderPipeline.mm
		src/Metal/MTLSamplerDescriptor.mm
		src/Metal/MTLSamplerState.mm
		src/Metal/MTLSharedEvent.mm
		src/Metal/MTLStencilDescriptor.mm
		src/Metal/MTLTexture.mm
		src/Metal/MTLTextureDescriptor.mm
		src/Metal/MTLTileRenderPipeline.mm
		src/Metal/MTLVertexDescriptor.mm
		src/Metal/Metal.mm

	DEPENDENCIES
		system
		objc
		Foundation
		IOSurface
		${METAL_LINK_INDIUM}
		${METAL_LINK_MSLC}
		cxx
)

set_target_properties(Metal
	PROPERTIES
		CXX_STANDARD 17
		CXX_STANDARD_REQUIRED ON
		CXX_EXTENSIONS OFF
)

target_include_directories(Metal PUBLIC
	include
)

target_include_directories(Metal PRIVATE
	private-include
)

# private API
add_library(Metal_private INTERFACE)
target_link_libraries(Metal_private INTERFACE
	Metal
)
target_include_directories(Metal_private INTERFACE
	private-include
)

if (BUILD_METAL)
	target_compile_definitions(Metal PUBLIC
		DARLING_METAL_ENABLED=1
	)
endif()

#
# MetalKit
#

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "113.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(MetalKit
	VERSION ${FRAMEWORK_VERSION}
	HEADER "include/MetalKit"
)

add_framework(MetalKit
	FAT
	CURRENT_VERSION
	VERSION ${FRAMEWORK_VERSION}

	SOURCES
		src/MetalKit/MTKModel.m
		src/MetalKit/MTKTextureLoader.m
		src/MetalKit/MTKView.m

	DEPENDENCIES
		AppKit
		system
		objc
		Foundation
		Metal
		QuartzCore
		CoreGraphics
		ImageIO
)

target_include_directories(MetalKit PUBLIC
	include
)

target_include_directories(MetalKit PRIVATE
	private-include
	${CMAKE_SOURCE_DIR}/src/external/foundation/internal_include
)

#
# MetalPerformanceShaders
#

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "122.5.6")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(MetalPerformanceShaders
	VERSION ${FRAMEWORK_VERSION}
	HEADER "include/MetalPerformanceShaders"
)

add_framework(MetalPerformanceShaders
	FAT
	CURRENT_VERSION
	VERSION ${FRAMEWORK_VERSION}

	SOURCES
		src/MPSKernel.m

	DEPENDENCIES
		system
		objc
		Foundation
		Metal
)

target_include_directories(MetalPerformanceShaders PUBLIC
	include
)

target_include_directories(MetalPerformanceShaders PRIVATE
	private-include
)
