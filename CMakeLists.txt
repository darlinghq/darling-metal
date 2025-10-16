project(metal)

remove_sdk_framework(Metal)
remove_sdk_framework(MetalKit)
remove_sdk_framework(MetalPerformanceShaders)

if (BUILD_METAL)
	add_subdirectory(deps/indium)
endif()

add_compile_options(
	-fvisibility=hidden
)

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
else()
	set(METAL_LINK_INDIUM "")
endif()

add_framework(Metal
	# Metal is not supported in 32-bit apps, but it does still link successfully into such apps.
	# thus, we have to provide a 32-bit build of the framework, but it doesn't have to provide any
	# functionality. so e.g. we can use modern objc features like non-fragile classes.
	FAT
	CURRENT_VERSION
	VERSION ${FRAMEWORK_VERSION}

	SOURCES
		src/Metal/Metal.mm
		src/Metal/MTLBuffer.mm
		src/Metal/MTLCommandBuffer.mm
		src/Metal/MTLCommandQueue.mm
		src/Metal/MTLCompileOptions.mm
		src/Metal/MTLComputeCommandEncoder.mm
		src/Metal/MTLComputePipeline.mm
		src/Metal/MTLDepthStencilDescriptor.mm
		src/Metal/MTLDevice.mm
		src/Metal/MTLDrawable.mm
		src/Metal/MTLLibrary.mm
		src/Metal/MTLPipeline.mm
		src/Metal/MTLRenderCommandEncoder.mm
		src/Metal/MTLRenderPipeline.mm
		src/Metal/MTLSamplerDescriptor.mm
		src/Metal/MTLStencilDescriptor.mm
		src/Metal/MTLTexture.mm
		src/Metal/MTLTextureDescriptor.mm
		src/Metal/MTLVertexDescriptor.mm

	DEPENDENCIES
		system
		objc
		Foundation
		${METAL_LINK_INDIUM}
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
		src/MetalKit/MTKView.m

	DEPENDENCIES
		AppKit
		system
		objc
		Foundation
		Metal
		QuartzCore
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
		src/dummy.c

	DEPENDENCIES
		system
		objc
		Foundation
		Metal
)

target_include_directories(MetalPerformanceShaders PUBLIC
	include
)
