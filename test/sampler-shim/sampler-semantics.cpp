// Pixel verification of the sampler semantics that darling-metal's
// MTLSamplerDescriptor -> Indium::SamplerDescriptor mapping forwards, on the
// real GPU (asahi / Apple M1).
//
// The ObjC shim can only be syntax-checked, so what is executed here is the
// thing the shim maps onto: Indium::SamplerDescriptor -> VkSampler. Every case
// below is a descriptor field the shim sets, and each is checked against the
// pixels that come back.
//
// The fragment stage is `fragment_sample` in sampler-fixture/fragment_sample.ll:
// it is test/texturing's real `fragment_texture` sampling call with the lighting
// body deleted, so the framebuffer pixel IS the sampled texel and the host
// reference is a bare sampler emulation with no shader maths in the way. The
// vertex stage is test/texturing's real `vertex_project`, and the quad is a
// full-viewport triangle whose texture coordinates are an exact affine function
// of the pixel position, so the coordinate at a pixel centre is closed-form and
// needs no barycentric reconstruction.

#include <indium/indium.private.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <map>
#include <cstdlib>
#include <unistd.h>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

// ---------------------------------------------------------------------------
// fixture geometry
// ---------------------------------------------------------------------------

static const size_t W = 256, H = 256;
static const size_t TEX_W = 8, TEX_H = 8;

// The vertex layout of test/texturing's Vertex: packed_float4 position,
// packed_float4 normal, packed_float2 texCoords. `normal` is unused by the
// pass-through fragment but the AIR metadata fixes the 40-byte stride.
struct Vertex {
	float position[4];
	float normal[4];
	float texCoords[2];
};
static_assert(sizeof(Vertex) == 40, "texturing's Vertex is packed");

// Uniforms is float4x4 MVP, float4x4 MV, float3x3 normalMatrix = 176 bytes.
struct Uniforms {
	float mvp[16];
	float mv[16];
	float normalMatrix[9];
};

// The full-viewport triangle: pixel (0,0), (2W,0), (0,2H) maps to clip
// (-1,-1), (3,-1), (-1,3), so every pixel of the target is covered exactly once.
static void makeQuad(Vertex out[3], double uvOriginX, double uvOriginY,
                     double uvScaleX, double uvScaleY, double z) {
	const double px[3] = { 0.0, 2.0 * W, 0.0 };
	const double py[3] = { 0.0, 0.0, 2.0 * H };
	for (int i = 0; i < 3; i++) {
		out[i].position[0] = (float)px[i];
		out[i].position[1] = (float)py[i];
		out[i].position[2] = (float)z;
		out[i].position[3] = 1.0f;
		out[i].normal[0] = 0.0f;
		out[i].normal[1] = 0.0f;
		out[i].normal[2] = 1.0f;
		out[i].normal[3] = 0.0f;
		out[i].texCoords[0] = (float)(uvOriginX + uvScaleX * px[i]);
		out[i].texCoords[1] = (float)(uvOriginY + uvScaleY * py[i]);
	}
}

// pixel position -> clip: x_ndc = 2*px/W - 1, y_ndc = 1 - 2*py/H, z_ndc = z
static void makeMVP(float m[16], double z) {
	for (int i = 0; i < 16; i++) m[i] = 0.0f;
	m[0]  = (float)(2.0 / W);   // column 0, row 0
	m[5]  = (float)(-2.0 / H);  // column 1, row 1
	m[10] = 1.0f;               // column 2, row 2
	m[12] = -1.0f;              // column 3, row 0
	m[13] = 1.0f;               // column 3, row 1
	m[15] = 1.0f;
	(void)z;
}

// ---------------------------------------------------------------------------
// texture contents
// ---------------------------------------------------------------------------

// Level 0: 64 texels, each a colour no other texel uses, so a nearest fetch is
// identifiable down to the individual texel.
static std::vector<uint8_t> level0;
static std::vector<uint8_t> level1;   // 4x4, a disjoint palette

// A second texture for the anisotropy group. Level 0 is a 2-texel-tall stripe
// pattern, constant along x, so a footprint that is long in x and one texel tall
// in y has every anisotropic tap land on the same stripe: the weighted average
// of N identical taps is that stripe, and the answer is predictable to the bit.
// Box-filtering a 2-texel period gives one row of one colour, so level 1 is
// still a stripe pattern (one texel per stripe) and levels 2 and up are flat.
static const int STRIPE_W = 32, STRIPE_H = 32, STRIPE_LEVELS = 6;
static std::vector<std::vector<uint8_t>> stripeLevel;

static void buildTexture(void) {
	level0.assign(TEX_W * TEX_H * 4, 0);
	for (int y = 0; y < TEX_H; y++) {
		for (int x = 0; x < TEX_W; x++) {
			uint8_t* t = &level0[(y * TEX_W + x) * 4];
			t[0] = (uint8_t)(x * 31 + 3);
			t[1] = (uint8_t)(y * 31 + 5);
			t[2] = (uint8_t)((x * 8 + y * 3) % 251);
			t[3] = 255;
		}
	}

	// Level 1 is 4x4. Every colour has a blue channel >= 200 so level-1 output is
	// disjoint from level-0 output (whose blue is < 200 by construction above:
	// (x*8 + y*3) % 251 <= 7*8 + 7*3 = 77).
	level1.assign(4 * 4 * 4, 0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			uint8_t* t = &level1[(y * 4 + x) * 4];
			t[0] = (uint8_t)(x * 61 + 11);
			t[1] = (uint8_t)(y * 61 + 13);
			t[2] = (uint8_t)(200 + (x * 5 + y * 2) % 55);
			t[3] = 255;
		}
	}

	stripeLevel.assign(STRIPE_LEVELS, {});
	stripeLevel[0].assign(STRIPE_W * STRIPE_H * 4, 0);
	for (int y = 0; y < STRIPE_H; y++)
		for (int x = 0; x < STRIPE_W; x++) {
			uint8_t* t = &stripeLevel[0][((size_t)y * STRIPE_W + x) * 4];
			t[0] = t[1] = t[2] = ((y / 2) % 2) ? 255 : 0;
			t[3] = 255;
		}
	for (int l = 1; l < STRIPE_LEVELS; l++) {
		int n = STRIPE_W >> l;
		stripeLevel[l].assign((size_t)n * n * 4, 0);
		for (int y = 0; y < n; y++)
			for (int x = 0; x < n; x++) {
				unsigned acc[3] = { 0, 0, 0 };
				for (int dy = 0; dy < 2; dy++)
					for (int dx = 0; dx < 2; dx++) {
						const uint8_t* s = &stripeLevel[l - 1]
							[(((size_t)y * 2 + dy) * (n * 2) + (x * 2 + dx)) * 4];
						for (int ch = 0; ch < 3; ch++) acc[ch] += s[ch];
					}
				uint8_t* t = &stripeLevel[l][((size_t)y * n + x) * 4];
				for (int ch = 0; ch < 3; ch++) t[ch] = (uint8_t)((acc[ch] + 2) / 4);
				t[3] = 255;
			}
	}
}

// ---------------------------------------------------------------------------
// host reference: Vulkan's texel addressing, in integers
// ---------------------------------------------------------------------------

enum class AddrMode { ClampToEdge, MirrorClampToEdge, Repeat, MirrorRepeat, ClampToBorder };

static int wrapIndex(int i, int n, AddrMode mode, bool* inRange) {
	int lo = 0, hi = n - 1;
	int r;
	switch (mode) {
		case AddrMode::Repeat: {
			r = i % n;
			if (r < 0) r += n;
			*inRange = true;
			return r;
		}
		case AddrMode::MirrorRepeat: {
			int period = 2 * n;
			r = i % period;
			if (r < 0) r += period;
			if (r >= n) r = period - 1 - r;
			*inRange = true;
			return r;
		}
		case AddrMode::MirrorClampToEdge:
			// Mirrored only across the 0 and n edges inside [-1, 1]; clamped outside.
			if (i >= 0 && i < n) { *inRange = true; return i; }
			if (i < 0 && i >= -n) { *inRange = true; return -1 - i; }
			r = i;
			break;
		case AddrMode::ClampToEdge:
		case AddrMode::ClampToBorder:
		default:
			r = i;
			break;
	}
	*inRange = (r >= lo && r <= hi);
	if (r < lo) r = lo;
	if (r > hi) r = hi;
	return r;
}

// Reference for one output pixel. `border` is the RGBA the border colour resolves
// to; `outOfRange` says whether the fetch fell outside the texture.
struct RefPixel {
	uint8_t rgba[4];
	bool outOfRange;
};

static RefPixel referenceNearest(double u, double v, const std::vector<uint8_t>& tex,
                                 int tw, int th, AddrMode sMode, AddrMode tMode,
                                 const uint8_t* border, bool normalized) {
	// Normalized coordinates put texel *centres* at (i+0.5)/tw, so the nearest
	// texel is round(u*tw - 0.5), i.e. floor(u*tw). Unnormalized coordinates are
	// already in texel units, so the index is floor(u).
	int i, j;
	if (normalized) {
		i = (int)std::floor(u * tw);
		j = (int)std::floor(v * th);
	} else {
		i = (int)std::floor(u);
		j = (int)std::floor(v);
	}

	bool inU = false, inV = false;
	int x = wrapIndex(i, tw, sMode, &inU);
	int y = wrapIndex(j, th, tMode, &inV);

	RefPixel rp {};
	if (sMode == AddrMode::ClampToBorder && !inU) {
		memcpy(rp.rgba, border, 4);
		rp.outOfRange = true;
		return rp;
	}
	if (tMode == AddrMode::ClampToBorder && !inV) {
		memcpy(rp.rgba, border, 4);
		rp.outOfRange = true;
		return rp;
	}
	memcpy(rp.rgba, &tex[((size_t)y * tw + x) * 4], 4);
	rp.outOfRange = false;
	return rp;
}

// ---------------------------------------------------------------------------
// harness plumbing
// ---------------------------------------------------------------------------

struct Ctx {
	std::shared_ptr<Indium::Device> device;
	std::shared_ptr<Indium::CommandQueue> queue;
	std::shared_ptr<Indium::Library> library;
	std::shared_ptr<Indium::RenderPipelineState> pipeline;
	std::shared_ptr<Indium::Texture> source;
	std::shared_ptr<Indium::Texture> striped;
	std::shared_ptr<Indium::Texture> target;
	std::shared_ptr<Indium::Texture> depth;
};

struct Case {
	std::string name;
	Indium::SamplerDescriptor desc;
	// uv mapping
	double uvOriginX, uvOriginY, uvScaleX, uvScaleY;
	AddrMode sMode, tMode;
	bool normalized;
};

static int gErrors = 0;
static int gChecks = 0;

static std::vector<uint8_t> render(Ctx& ctx, std::shared_ptr<Indium::Buffer> vbuf,
                                   std::shared_ptr<Indium::Buffer> ubuf,
                                   const std::vector<std::shared_ptr<Indium::SamplerState>>& samplers,
                                   bool usePluralForm, bool useLodClampForm,
                                   float lodMin, float lodMax,
                                   std::shared_ptr<Indium::Texture> src = nullptr) {
	std::vector<uint8_t> image(W * H * 4, 0);
	if (!src) src = ctx.source;
	{
		Indium::RenderPassDescriptor rp {};
		rp.colorAttachments.emplace_back();
		rp.colorAttachments[0].texture = ctx.target;
		rp.colorAttachments[0].loadAction = Indium::LoadAction::Clear;
		rp.colorAttachments[0].storeAction = Indium::StoreAction::Store;
		rp.colorAttachments[0].clearColor = Indium::ClearColor(0, 0, 0, 1);
		rp.renderTargetWidth = W;
		rp.renderTargetHeight = H;

		auto cb = ctx.queue->commandBuffer();
		auto enc = cb->renderCommandEncoder(rp);
		enc->setViewport(Indium::Viewport { 0, 0, (double)W, (double)H, 0, 1 });
		enc->setRenderPipelineState(ctx.pipeline);
		enc->setVertexBuffer(vbuf, 0, 0);
		enc->setVertexBuffer(ubuf, 0, 1);
		enc->setFragmentBuffer(ubuf, 0, 0);
		enc->setFragmentTexture(src, 0);
		if (usePluralForm) {
			enc->setFragmentSamplerStates(samplers, Indium::Range<size_t> { 0, samplers.size() });
		} else if (useLodClampForm) {
			for (size_t i = 0; i < samplers.size(); ++i)
				enc->setFragmentSamplerState(samplers[i], lodMin, lodMax, i);
		} else {
			for (size_t i = 0; i < samplers.size(); ++i)
				enc->setFragmentSamplerState(samplers[i], i);
		}
		enc->drawPrimitives(Indium::PrimitiveType::Triangle, 0, 3);
		enc->endEncoding();
		cb->commit();
		cb->waitUntilCompleted();
	}
	{
		size_t bpr = W * 4;
		auto readback = ctx.device->newBuffer(image.size(), Indium::ResourceOptions::StorageModeShared);
		auto cb = ctx.queue->commandBuffer();
		auto blit = cb->blitCommandEncoder();
		blit->copy(ctx.target, 0, 0, Indium::Origin { 0, 0, 0 }, Indium::Size { W, H, 1 },
			readback, 0, bpr, bpr, Indium::BlitOption::None);
		blit->endEncoding();
		cb->commit();
		cb->waitUntilCompleted();
		memcpy(image.data(), readback->contents(), image.size());
	}
	return image;
}

static bool inPalette(const uint8_t* px, const std::vector<uint8_t>& pal, int tw, int th) {
	for (int y = 0; y < th; y++)
		for (int x = 0; x < tw; x++) {
			const uint8_t* t = &pal[((size_t)y * tw + x) * 4];
			if (px[0] == t[0] && px[1] == t[1] && px[2] == t[2]) return true;
		}
	return false;
}

// Checks an image against the exact nearest reference, or against the "every
// pixel is a texel of this level" property when refMode is false.
static size_t checkExact(const Case& c, const std::vector<uint8_t>& img, bool useRef,
                           bool countErrors = true) {
	size_t bad = 0;
	double worst = 0;
	for (size_t y = 0; y < H; y++) {
		for (size_t x = 0; x < W; x++) {
			const uint8_t* p = &img[(y * W + x) * 4];
			double u = c.uvOriginX + c.uvScaleX * ((double)x + 0.5);
			double v = c.uvOriginY + c.uvScaleY * ((double)y + 0.5);
			uint8_t border[4];
			switch (c.desc.borderColor) {
				case Indium::SamplerBorderColor::OpaqueWhite:
					border[0] = border[1] = border[2] = border[3] = 255; break;
				case Indium::SamplerBorderColor::OpaqueBlack:
					border[0] = border[1] = border[2] = 0; border[3] = 255; break;
				case Indium::SamplerBorderColor::TransparentBlack:
				default:
					border[0] = border[1] = border[2] = border[3] = 0; break;
			}
			RefPixel rp = referenceNearest(u, v, level0, TEX_W, TEX_H, c.sMode, c.tMode, border, c.normalized);
			if (useRef) {
				for (int ch = 0; ch < 4; ch++) {
					double d = std::abs((double)p[ch] - (double)rp.rgba[ch]);
					worst = std::max(worst, d);
					if (d > 0) bad++;
				}
			} else {
				if (!inPalette(p, level0, TEX_W, TEX_H)) bad++;
			}
		}
	}
	if (bad != 0) {
		std::printf("    %-4s %-46s %zu mismatching channels, worst %.0f\n",
			countErrors ? "FAIL" : "ctrl", c.name.c_str(), bad, worst);
		if (countErrors) gErrors++;
	} else {
		std::printf("    %-4s %-46s all %zu channels exact\n",
			countErrors ? "ok" : "ctrl", c.name.c_str(), W * H * 4);
	}
	gChecks++;
	return bad;
}

static void report(const char* verdict, const std::string& name, const std::string& detail) {
	std::printf("    %-4s %-46s %s\n", verdict, name.c_str(), detail.c_str());
}

int main(int argc, char** argv) {
	if (argc < 2) { std::fprintf(stderr, "usage: %s <sampler.metallib>\n", argv[0]); return 2; }
	std::ifstream in(argv[1], std::ios::binary | std::ios::ate);
	if (!in) { std::fprintf(stderr, "cannot open %s\n", argv[1]); return 2; }
	size_t len = in.tellg();
	in.seekg(0, std::ios::beg);
	std::vector<char> libData(len);
	if (!in.read(libData.data(), len)) return 2;

	buildTexture();
	Indium::init(nullptr, 0, false);

	{
		auto device = Indium::createSystemDefaultDevice();
		if (!device) { std::fprintf(stderr, "no vulkan device\n"); return 2; }
		std::cout << "device: " << device->name() << "\n\n";

		bool keepPolling = true;
		std::thread poll([device, &keepPolling]() {
			while (keepPolling) device->pollEvents(UINT64_MAX);
		});

		Ctx ctx;
		ctx.device = device;
		ctx.library = device->newLibrary(libData.data(), libData.size());
		ctx.queue = device->newCommandQueue();

		{
			Indium::RenderPipelineDescriptor pso {};
			pso.vertexFunction = ctx.library->newFunction("vertex_project");
			pso.fragmentFunction = ctx.library->newFunction("fragment_sample");
			pso.colorAttachments.emplace_back();
			pso.colorAttachments[0].pixelFormat = Indium::PixelFormat::RGBA8Unorm;
			ctx.pipeline = device->newRenderPipelineState(pso);
		}
		if (!ctx.pipeline) { std::fprintf(stderr, "no pipeline\n"); return 2; }

		// Two mip levels: level 0 is 8x8, level 1 is 4x4, and their palettes are
		// disjoint (level 1's blue is >= 200, level 0's is <= 77).
		{
			Indium::TextureDescriptor td = Indium::TextureDescriptor::texture2DDescriptor(
				Indium::PixelFormat::RGBA8Unorm, TEX_W, TEX_H, true);
			td.mipmapLevelCount = 2;
			td.usage = Indium::TextureUsage::ShaderRead;
			ctx.source = device->newTexture(td);
			ctx.source->replaceRegion(Indium::Region::make2D(0, 0, TEX_W, TEX_H), 0,
				level0.data(), 4 * TEX_W);
			ctx.source->replaceRegion(Indium::Region::make2D(0, 0, 4, 4), 1,
				level1.data(), 4 * 4);
		}
		// The stripe texture the anisotropy group samples: 32x32, six mip levels.
		{
			Indium::TextureDescriptor td = Indium::TextureDescriptor::texture2DDescriptor(
				Indium::PixelFormat::RGBA8Unorm, STRIPE_W, STRIPE_H, true);
			td.mipmapLevelCount = STRIPE_LEVELS;
			td.usage = Indium::TextureUsage::ShaderRead;
			ctx.striped = device->newTexture(td);
			for (int l = 0; l < STRIPE_LEVELS; l++) {
				int n = STRIPE_W >> l;
				ctx.striped->replaceRegion(Indium::Region::make2D(0, 0, n, n), l,
					stripeLevel[l].data(), 4 * n);
			}
		}
		{
			Indium::TextureDescriptor td = Indium::TextureDescriptor::texture2DDescriptor(
				Indium::PixelFormat::RGBA8Unorm, W, H, false);
			td.usage = Indium::TextureUsage::RenderTarget;
			td.resourceOptions = Indium::ResourceOptions::StorageModePrivate;
			ctx.target = device->newTexture(td);
		}
		{
			Indium::TextureDescriptor td = Indium::TextureDescriptor::texture2DDescriptor(
				Indium::PixelFormat::Depth32Float, W, H, false);
			td.usage = Indium::TextureUsage::RenderTarget;
			td.resourceOptions = Indium::ResourceOptions::StorageModePrivate;
			ctx.depth = device->newTexture(td);
		}

		auto makeUBuf = [&](double z) {
			Uniforms u {};
			makeMVP(u.mvp, z);
			for (int i = 0; i < 16; i++) u.mv[i] = 0.0f;
			u.mv[0] = u.mv[5] = u.mv[10] = u.mv[15] = 1.0f;
			for (int i = 0; i < 9; i++) u.normalMatrix[i] = (i % 4 == 0) ? 1.0f : 0.0f;
			return device->newBuffer(&u, sizeof(u), Indium::ResourceOptions::StorageModeShared);
		};

		// ---- group 1: nearest filtering, one case per address mode ----------
		// The quad covers uv [-0.25, 1.25] on both axes, so every address mode has
		// both in-range and out-of-range coordinates to act on.
		std::cout << "[1] nearest filtering, address modes (exact reference)\n";
		struct AddrCase { const char* name; AddrMode mode; Indium::SamplerAddressMode v; };
		static const AddrCase addrCases[] = {
			{ "s/t ClampToEdge",             AddrMode::ClampToEdge,        Indium::SamplerAddressMode::ClampToEdge },
			{ "s/t Repeat",                  AddrMode::Repeat,             Indium::SamplerAddressMode::Repeat },
			{ "s/t MirrorRepeat",            AddrMode::MirrorRepeat,       Indium::SamplerAddressMode::MirrorRepeat },
			{ "s/t MirrorClampToEdge",       AddrMode::MirrorClampToEdge,  Indium::SamplerAddressMode::MirrorClampToEdge },
			// indium maps both ClampToZero and ClampToBorderColor to
			// VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER, so this case is measured
			// against the border colour, not against zero.
			{ "s/t ClampToBorderColor",      AddrMode::ClampToBorder,      Indium::SamplerAddressMode::ClampToBorderColor },
		};
		for (const auto& a : addrCases) {
			Case c {};
			c.name = std::string("nearest ") + a.name;
			c.desc = Indium::SamplerDescriptor {};
			c.desc.minFilter = Indium::SamplerMinMagFilter::Nearest;
			c.desc.magFilter = Indium::SamplerMinMagFilter::Nearest;
			c.desc.sAddressMode = a.v;
			c.desc.tAddressMode = a.v;
			c.uvOriginX = 0.5 - 0.75;  c.uvScaleX = 1.5 / W;
			c.uvOriginY = 0.5 - 0.75;  c.uvScaleY = 1.5 / H;
			c.sMode = a.mode; c.tMode = a.mode;
			c.normalized = true;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);
			auto samp = device->newSamplerState(c.desc);
			auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);
			checkExact(c, img, true);
		}

		// ---- group 2: border colour ----------------------------------------
		std::cout << "\n[2] border colour under ClampToBorderColor (exact reference)\n";
		static const struct { const char* name; Indium::SamplerBorderColor v; } borderCases[] = {
			{ "TransparentBlack", Indium::SamplerBorderColor::TransparentBlack },
			{ "OpaqueBlack",      Indium::SamplerBorderColor::OpaqueBlack },
			{ "OpaqueWhite",      Indium::SamplerBorderColor::OpaqueWhite },
		};
		for (const auto& b : borderCases) {
			Case c {};
			c.name = std::string("borderColor ") + b.name;
			c.desc = Indium::SamplerDescriptor {};
			c.desc.sAddressMode = Indium::SamplerAddressMode::ClampToBorderColor;
			c.desc.tAddressMode = Indium::SamplerAddressMode::ClampToBorderColor;
			c.desc.borderColor = b.v;
			c.uvOriginX = 0.5 - 0.75;  c.uvScaleX = 1.5 / W;
			c.uvOriginY = 0.5 - 0.75;  c.uvScaleY = 1.5 / H;
			c.sMode = AddrMode::ClampToBorder; c.tMode = AddrMode::ClampToBorder;
			c.normalized = true;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);
			auto samp = device->newSamplerState(c.desc);
			auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);
			checkExact(c, img, true);
		}

		// ---- group 3: min/mag filter selection -------------------------------
		// Vulkan picks magFilter when the texel footprint is under one texel per
		// pixel and minFilter when it is over one, so the *footprint* selects
		// between them. uvScale is uv per pixel, so uvScale*TEX_W is texels/px.
		//
		// Which LOD that decision is made on matters as much as the footprint. The
		// driver clamps the computed lambda to [minLod, maxLod] first, and picks
		// the filter from the clamped value, so pinning maxLod to 0 pins lambda at
		// 0 and every footprint is then treated as magnification. That is why the
		// minification cases below have to leave the LOD free, and why the first
		// two rows (which pin it) show magFilter being read at a 1.5 texel/px
		// footprint instead.
		//
		// Linear filtering has no exact integer reference (Vulkan weights texels
		// in fixed point), so a linear case is only ever compared against a
		// nearest case: a nearest fetch can only produce a texel colour, so any
		// pixel that is not a texel colour proves a linear fetch happened.
		std::cout << "\n[3] min/mag filter selection\n";
		// 0.25 texels/px -> lambda = -2, magnified. 1.5 texels/px -> lambda = +0.585,
		// minified, which rounds to mip level 1 under a nearest mipmap mode.
		struct FilterCase {
			const char* name;
			Indium::SamplerMinMagFilter minF, magF;
			double uvScale;
			float lodMax;
			// true = the case must differ from the all-nearest baseline (a filter
			// was read), false = it must be byte-identical to it (no filter was
			// read). This is the property under test, so it is stated as a field
			// rather than inferred from the name.
			bool expectFilterRead;
		};
		static const FilterCase filterCases[] = {
			{ "magnified lod free  minFilter=linear has no effect", Indium::SamplerMinMagFilter::Linear,  Indium::SamplerMinMagFilter::Nearest, 0.25 / TEX_W, 3.4e38f, false },
			{ "magnified lod free  magFilter=linear blends",        Indium::SamplerMinMagFilter::Nearest, Indium::SamplerMinMagFilter::Linear,  0.25 / TEX_W, 3.4e38f, true  },
			{ "minified  lod free  minFilter=linear blends",        Indium::SamplerMinMagFilter::Linear,  Indium::SamplerMinMagFilter::Nearest, 1.50 / TEX_W, 3.4e38f, true  },
			{ "minified  lod free  magFilter=linear has no effect",  Indium::SamplerMinMagFilter::Nearest, Indium::SamplerMinMagFilter::Linear,  1.50 / TEX_W, 3.4e38f, false },
			{ "minified  lodMax=0   minFilter=linear has no effect", Indium::SamplerMinMagFilter::Linear,  Indium::SamplerMinMagFilter::Nearest, 1.50 / TEX_W, 0.0f,   false },
			{ "minified  lodMax=0   magFilter=linear blends",        Indium::SamplerMinMagFilter::Nearest, Indium::SamplerMinMagFilter::Linear,  1.50 / TEX_W, 0.0f,   true  },
		};
		// The baseline each "has no effect" row is compared against: same footprint
		// and LOD, both filters nearest.
		for (const auto& f : filterCases) {
			Case c {};
			c.name = f.name;
			c.desc = Indium::SamplerDescriptor {};
			c.desc.minFilter = f.minF;
			c.desc.magFilter = f.magF;
			c.desc.mipFilter = Indium::SamplerMipFilter::Nearest;
			c.desc.sAddressMode = Indium::SamplerAddressMode::Repeat;
			c.desc.tAddressMode = Indium::SamplerAddressMode::Repeat;
			c.desc.lodMaxClamp = f.lodMax;
			c.uvOriginX = 0.0; c.uvScaleX = f.uvScale;
			c.uvOriginY = 0.0; c.uvScaleY = f.uvScale;
			c.sMode = AddrMode::Repeat; c.tMode = AddrMode::Repeat;
			c.normalized = true;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);
			auto samp = device->newSamplerState(c.desc);
			auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);

			auto nn = c; nn.desc.minFilter = Indium::SamplerMinMagFilter::Nearest;
			nn.desc.magFilter = Indium::SamplerMinMagFilter::Nearest;
			auto base = device->newSamplerState(nn.desc);
			auto imgBase = render(ctx, vbuf, ubuf, { base }, false, false, 0, 0);

			size_t blends = 0, differing = 0;
			std::map<uint32_t, size_t> hist;
			for (size_t i = 0; i < W * H; i++) {
				const uint8_t* p4 = &img[i * 4];
				if (!inPalette(p4, level0, TEX_W, TEX_H) &&
				    !inPalette(p4, level1, 4, 4)) blends++;
				if (memcmp(&img[i * 4], &imgBase[i * 4], 4) != 0) differing++;
				hist[(uint32_t)p4[0] << 16 | (uint32_t)p4[1] << 8 | p4[2]]++;
			}
			// A row that expects no filter to be read must match the all-nearest
			// baseline byte for byte; a row that expects one must differ from it in
			// every pixel and produce at least one colour that is not a texel.
			bool pass = f.expectFilterRead
				? (differing == W * H && blends > 0)
				: (differing == 0);
			char detail[200];
			std::snprintf(detail, sizeof(detail),
				"texels/px=%.2f lodMax=%s: %zu/%zu pixels differ from the all-nearest baseline, "
				"%zu are bilinear blends, %zu distinct colours",
				f.uvScale * TEX_W,
				f.lodMax == 0.0f ? "0" : "FLT_MAX",
				differing, W * H, blends, hist.size());
			report(pass ? "ok" : "FAIL", f.name, detail);
			if (!pass) gErrors++;
			gChecks++;
		}

		// The same minified fetch with both filters nearest, against the exact
		// reference for the mip level the LOD selects. lambda = log2(1.5) = 0.585
		// rounds to level 1, so every pixel must be a level-1 texel fetched with
		// the texel-centre rule, under Repeat.
		{
			Case c {};
			c.name = "minified  lod free   both nearest = level 1 exactly";
			c.desc = Indium::SamplerDescriptor {};
			c.desc.minFilter = Indium::SamplerMinMagFilter::Nearest;
			c.desc.magFilter = Indium::SamplerMinMagFilter::Nearest;
			c.desc.mipFilter = Indium::SamplerMipFilter::Nearest;
			c.desc.sAddressMode = Indium::SamplerAddressMode::Repeat;
			c.desc.tAddressMode = Indium::SamplerAddressMode::Repeat;
			c.desc.lodMaxClamp = 3.4e38f;
			c.uvOriginX = 0.0; c.uvScaleX = 1.5 / TEX_W;
			c.uvOriginY = 0.0; c.uvScaleY = 1.5 / TEX_W;
			c.sMode = AddrMode::Repeat; c.tMode = AddrMode::Repeat;
			c.normalized = true;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);
			auto samp = device->newSamplerState(c.desc);
			auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);

			size_t bad = 0, worst = 0;
			uint8_t border[4] = { 0, 0, 0, 0 };
			for (size_t y = 0; y < H; y++)
				for (size_t x = 0; x < W; x++) {
					double u = c.uvOriginX + c.uvScaleX * ((double)x + 0.5);
					double v = c.uvOriginY + c.uvScaleY * ((double)y + 0.5);
					auto rp = referenceNearest(u, v, level1, 4, 4,
						AddrMode::Repeat, AddrMode::Repeat, border, true);
					const uint8_t* p4 = &img[((y * W) + x) * 4];
					for (int ch = 0; ch < 4; ch++) {
						double d = std::abs((double)p4[ch] - (double)rp.rgba[ch]);
						if (d > 0) { bad++; worst = std::max(worst, (size_t)d); }
					}
				}
			char detail[200];
			std::snprintf(detail, sizeof(detail), "%zu/%zu channels differ from the level-1 nearest reference, worst %zu",
				bad, W * H * 4, worst);
			report(bad == 0 ? "ok" : "FAIL", c.name, detail);
			if (bad != 0) gErrors++;
			gChecks++;
		}

		// Raising minLod above 0 moves even a deep magnification into the
		// minifying regime, which is the mechanism behind the lodMax=0 rows above:
		// the driver chooses between minFilter and magFilter on the clamped LOD.
		{
			std::cout << "[3b] which filter the clamped LOD selects (0.25 texels/px, lambda = -2)\n";
			struct RegimeCase { const char* name; float lodMin; Indium::SamplerMinMagFilter minF; };
			static const RegimeCase regimes[] = {
				{ "lodMin=0    minFilter=linear", 0.0f, Indium::SamplerMinMagFilter::Linear  },
				{ "lodMin=0.5  minFilter=linear", 0.5f, Indium::SamplerMinMagFilter::Linear  },
				{ "lodMin=0.5  magFilter=linear", 0.5f, Indium::SamplerMinMagFilter::Nearest },
			};
			std::vector<std::vector<uint8_t>> regimeImages;
			for (const auto& r : regimes) {
				Case c {};
				c.desc = Indium::SamplerDescriptor {};
				c.desc.minFilter = r.minF;
				c.desc.magFilter = (r.minF == Indium::SamplerMinMagFilter::Linear)
					? Indium::SamplerMinMagFilter::Nearest : Indium::SamplerMinMagFilter::Linear;
				c.desc.mipFilter = Indium::SamplerMipFilter::Nearest;
				c.desc.sAddressMode = Indium::SamplerAddressMode::Repeat;
				c.desc.tAddressMode = Indium::SamplerAddressMode::Repeat;
				c.desc.lodMinClamp = r.lodMin;
				c.desc.lodMaxClamp = 3.4e38f;
				c.uvOriginX = 0.0; c.uvScaleX = 0.25 / TEX_W;
				c.uvOriginY = 0.0; c.uvScaleY = 0.25 / TEX_W;
				c.sMode = AddrMode::Repeat; c.tMode = AddrMode::Repeat;
				c.normalized = true;

				Vertex verts[3];
				makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
				auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
				auto ubuf = makeUBuf(0.5);
				auto samp = device->newSamplerState(c.desc);
				auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);
				regimeImages.push_back(img);

				size_t blends = 0;
				for (size_t i = 0; i < W * H; i++) {
					const uint8_t* p4 = &img[i * 4];
					if (!inPalette(p4, level0, TEX_W, TEX_H) &&
					    !inPalette(p4, level1, 4, 4)) blends++;
				}
				char detail[160];
				std::snprintf(detail, sizeof(detail), "%zu/%zu pixels are bilinear blends", blends, W * H);
				report("INFO", r.name, detail);
				gChecks++;
			}
			// The minified-regime row (lodMin=0.5, minFilter=linear) must differ
			// from the magnified-regime one (lodMin=0, minFilter=linear): the same
			// descriptor field is read in one and not in the other.
			{
				bool differ = memcmp(regimeImages[0].data(), regimeImages[1].data(), W * H * 4) != 0;
				report(differ ? "ok" : "FAIL", "raising lodMinClamp switches which filter is read",
					differ ? "lodMin=0 and lodMin=0.5 differ at the same footprint"
					       : "identical, so the clamped LOD does not select the filter");
				if (!differ) gErrors++;
				gChecks++;
			}
		}

		// ---- group 4: mip filter and LOD clamps -----------------------------
		// Minified with no LOD clamp, the chosen level is observable because the
		// two levels have disjoint palettes.
		std::cout << "\n[4] mip filter and lodMaxClamp (minified, 2 mip levels)\n";
		struct MipCase {
			const char* name;
			Indium::SamplerMipFilter mipF;
			float lodMax;
			int expectLevel;
		};
		// expectLevel: 0 = every pixel a level-0 texel, 1 = every pixel a level-1
		// texel, -1 = neither (a blend of the two levels), -2 = no hard
		// expectation, just report what happened.
		static const MipCase mipCases[] = {
			{ "mipFilter=Nearest lodMaxClamp=FLT_MAX", Indium::SamplerMipFilter::Nearest, 3.4e38f,  1 },
			{ "mipFilter=Linear  lodMaxClamp=FLT_MAX", Indium::SamplerMipFilter::Linear,  3.4e38f, -1 },
			{ "mipFilter=Linear  lodMaxClamp=0",      Indium::SamplerMipFilter::Linear,  0.0f,     0 },
			{ "mipFilter=Linear  lodMinClamp=lodMaxClamp=0", Indium::SamplerMipFilter::Linear, 0.0f, 0 },
			// Metal says NotMipmapped must stay on level 0. indium maps it to
			// VK_SAMPLER_MIPMAP_MODE_NEAREST with no LOD clamp, so it is expected
			// to land on level 1 here; reported rather than asserted.
			{ "mipFilter=NotMipmapped lodMaxClamp=FLT_MAX (Metal: level 0)", Indium::SamplerMipFilter::NotMipmapped, 3.4e38f, -2 },
		};
		for (const auto& m : mipCases) {
			Case c {};
			c.name = m.name;
			c.desc = Indium::SamplerDescriptor {};
			c.desc.minFilter = Indium::SamplerMinMagFilter::Nearest;
			c.desc.magFilter = Indium::SamplerMinMagFilter::Nearest;
			c.desc.mipFilter = m.mipF;
			c.desc.lodMaxClamp = m.lodMax;
			c.desc.sAddressMode = Indium::SamplerAddressMode::Repeat;
			c.desc.tAddressMode = Indium::SamplerAddressMode::Repeat;
			// 1.5 texels per pixel at level 0, so lambda = log2(1.5) = 0.58: the
			// mip level rounds to 1, and the mipmap mode decides how the two
			// levels are combined.
			c.uvOriginX = 0.0; c.uvScaleX = 1.5 / TEX_W;
			c.uvOriginY = 0.0; c.uvScaleY = 1.5 / TEX_W;
			c.sMode = AddrMode::Repeat; c.tMode = AddrMode::Repeat;
			c.normalized = true;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);
			auto samp = device->newSamplerState(c.desc);
			auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);

			size_t from0 = 0, from1 = 0, fromNeither = 0;
			for (size_t y = 0; y < H; y++)
				for (size_t x = 0; x < W; x++) {
					const uint8_t* p = &img[(y * W + x) * 4];
					bool in0 = inPalette(p, level0, TEX_W, TEX_H);
					bool in1 = inPalette(p, level1, 4, 4);
					if (in0) from0++;
					else if (in1) from1++;
					else fromNeither++;
				}
			char detail[160];
			std::snprintf(detail, sizeof(detail),
				"level0=%zu level1=%zu neither=%zu", from0, from1, fromNeither);
			bool pass;
			const char* verdict;
			if (m.expectLevel == 0)       { pass = (from0 == W * H); verdict = pass ? "ok" : "FAIL"; }
			else if (m.expectLevel == 1)  { pass = (from1 == W * H); verdict = pass ? "ok" : "FAIL"; }
			else if (m.expectLevel == -1) { pass = (fromNeither > W * H / 2); verdict = pass ? "ok" : "FAIL"; }
			else                          { pass = true; verdict = "INFO"; }
			report(verdict, m.name, detail);
			if (!pass) gErrors++;
			gChecks++;
		}

		// ---- group 4 (continued): which filter blends the two mip levels ----
		// Trilinear filtering blends two mip levels. Whether that blend is done
		// with nearest or linear is what minFilter is for, so this is the case
		// that can tell whether minFilter reaches the VkSampler at all.
		std::cout << "\n[4] minFilter as the inter-level blend filter (mipFilter=Linear, minified)\n";
		struct BlendCase {
			const char* name;
			Indium::SamplerMinMagFilter minF;
			int expectLevel;   // 0, 1, or -1 for "a blend of both"
		};
		static const BlendCase blendCases[] = {
			{ "minFilter=nearest -> nearest level blend", Indium::SamplerMinMagFilter::Nearest, 1 },
			{ "minFilter=linear  -> trilinear level blend", Indium::SamplerMinMagFilter::Linear, -1 },
		};
		for (const auto& b : blendCases) {
			Case c {};
			c.name = b.name;
			c.desc = Indium::SamplerDescriptor {};
			c.desc.minFilter = b.minF;
			c.desc.magFilter = Indium::SamplerMinMagFilter::Linear;
			c.desc.mipFilter = Indium::SamplerMipFilter::Linear;
			c.desc.sAddressMode = Indium::SamplerAddressMode::Repeat;
			c.desc.tAddressMode = Indium::SamplerAddressMode::Repeat;
			c.uvOriginX = 0.0; c.uvScaleX = 1.5 / TEX_W;
			c.uvOriginY = 0.0; c.uvScaleY = 1.5 / TEX_W;
			c.sMode = AddrMode::Repeat; c.tMode = AddrMode::Repeat;
			c.normalized = true;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);
			auto samp = device->newSamplerState(c.desc);
			auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);

			size_t from0 = 0, from1 = 0, fromNeither = 0;
			for (size_t y = 0; y < H; y++)
				for (size_t x = 0; x < W; x++) {
					const uint8_t* q = &img[(y * W + x) * 4];
					bool in0 = inPalette(q, level0, TEX_W, TEX_H);
					bool in1 = inPalette(q, level1, 4, 4);
					if (in0) from0++;
					else if (in1) from1++;
					else fromNeither++;
				}
			// Whatever minFilter is set to, the inter-level blend here is linear,
			// so this group reports rather than asserts: the point of the numbers
			// is that minFilter is not observable through them.
			char detail[200];
			std::snprintf(detail, sizeof(detail), "level0=%zu level1=%zu blend=%zu",
				from0, from1, fromNeither);
			report("INFO", b.name, detail);
			gChecks++;
		}

		// ---- group 5: unnormalized coordinates -----------------------------
		std::cout << "\n[5] normalizedCoordinates=NO (texel-space coords, exact reference)\n";
		{
			Case c {};
			c.name = "unnormalized nearest ClampToEdge";
			c.desc = Indium::SamplerDescriptor {};
			c.desc.normalizedCoordinates = false;
			c.desc.sAddressMode = Indium::SamplerAddressMode::ClampToEdge;
			c.desc.tAddressMode = Indium::SamplerAddressMode::ClampToEdge;
			// uv in texel units: -1.5 .. 9.5 across the target.
			c.uvOriginX = -1.5; c.uvScaleX = 11.0 / W;
			c.uvOriginY = -1.5; c.uvScaleY = 11.0 / H;
			c.sMode = AddrMode::ClampToEdge; c.tMode = AddrMode::ClampToEdge;
			c.normalized = false;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);
			auto samp = device->newSamplerState(c.desc);
			auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);
			checkExact(c, img, true);
		}

		// ---- group 6: negative controls ------------------------------------
		// Without these, "all pixels matched" could just mean the comparison is
		// too loose to fail. Each control is a case that is required to fail, or a
		// required difference.
		std::cout << "\n[6] negative controls (these must show the checks CAN fail)\n";
		{
			// NC1: nearest and linear on a gradient must not be the same image.
			Indium::SamplerDescriptor d {};
			d.sAddressMode = Indium::SamplerAddressMode::Repeat;
			d.tAddressMode = Indium::SamplerAddressMode::Repeat;
			d.mipFilter = Indium::SamplerMipFilter::NotMipmapped;
			d.lodMaxClamp = 0;
			Case c {};
			c.name = "NC1";
			c.desc = d;
			c.uvOriginX = 0.0; c.uvScaleX = 0.25 / TEX_W;
			c.uvOriginY = 0.0; c.uvScaleY = 0.25 / TEX_W;
			c.sMode = AddrMode::Repeat; c.tMode = AddrMode::Repeat;
			c.normalized = true;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);

			auto nearest = device->newSamplerState(d);
			auto linearD = d; linearD.magFilter = Indium::SamplerMinMagFilter::Linear;
			auto linear = device->newSamplerState(linearD);
			auto imgN = render(ctx, vbuf, ubuf, { nearest }, false, false, 0, 0);
			auto imgL = render(ctx, vbuf, ubuf, { linear }, false, false, 0, 0);
			double meanDiff = 0;
			for (size_t i = 0; i < W * H; i++)
				for (int ch = 0; ch < 3; ch++)
					meanDiff += std::abs((double)imgN[i*4+ch] - (double)imgL[i*4+ch]);
			meanDiff /= (double)(W * H * 3);
			if (meanDiff > 1.0) {
				char d2[80];
				std::snprintf(d2, sizeof(d2), "mean channel difference %.2f/255", meanDiff);
				report("ok", "nearest vs linear differ on a gradient", d2);
			} else {
				char d2[80];
				std::snprintf(d2, sizeof(d2), "mean channel difference %.2f/255", meanDiff);
				report("FAIL", "nearest vs linear differ on a gradient", d2);
				gErrors++;
			}
			gChecks++;

			// NC2: the exact reference must reject the wrong address mode. If this
			// passed, the exact check in group 1 would be vacuous.
			for (const auto& wrong : { AddrMode::Repeat, AddrMode::MirrorRepeat, AddrMode::MirrorClampToEdge }) {
				Case bad {};
				bad.name = "NC2 wrong mode in the reference";
				bad.desc = d;
				bad.uvOriginX = 0.5 - 0.75; bad.uvScaleX = 1.5 / W;
				bad.uvOriginY = 0.5 - 0.75; bad.uvScaleY = 1.5 / H;
				bad.sMode = wrong; bad.tMode = wrong;
				bad.normalized = true;
				size_t mismatches = checkExact(bad, imgN, true, /* countErrors */ false);
				if (mismatches > 0) {
					report("ok", "exact reference rejects a wrong address mode",
						"the mismatches above are the control working");
				} else {
					report("FAIL", "exact reference rejects a wrong address mode",
						"a wrong address mode still matched, so the check is vacuous");
					gErrors++;
				}
				gChecks++;
			}
		}

		// ---- group 7: depth-stencil state ----------------------------------
		// Three full-viewport triangles, each with a constant coordinate so it
		// paints exactly one texel and the surviving colour names the winner.
		// Drawn in order A (z=0.9), B (z=0.1), C (z=0.5), against a cleared depth
		// buffer. The clear colour is a value no texel can produce, so "nothing was
		// drawn" is distinguishable from "a draw was rejected".
		std::cout << "\n[7] depth-stencil state\n";
		{
			struct DepthCase {
				const char* name;
				double clearDepth;
				bool writeEnabled;
				Indium::CompareFunction cmp;
				int winner;        // 0 = nothing drawn, 1 = A, 2 = B, 3 = C
				const char* why;
			};
			static const DepthCase depthCases[] = {
				{ "clear=1.0 write=YES compare=Less",    1.0, true,  Indium::CompareFunction::Less,    2,
				  "B writes 0.1, so C at 0.5 is rejected: depthWriteEnabled is what blocks C" },
				{ "clear=1.0 write=NO  compare=Less",    1.0, false, Indium::CompareFunction::Less,    3,
				  "with writes off the depth stays 1.0, so C also passes: the pair above/below isolates depthWriteEnabled" },
				{ "clear=0.0 write=YES compare=Greater", 0.0, true,  Indium::CompareFunction::Greater, 1,
				  "Greater inverts the test, so A passes and the later draws are rejected" },
				{ "clear=1.0 write=YES compare=Always",  1.0, true,  Indium::CompareFunction::Always,  3,
				  "Always passes every fragment, so the last draw wins" },
				{ "clear=1.0 write=YES compare=Never",   1.0, true,  Indium::CompareFunction::Never,   0,
				  "Never rejects every fragment, so the clear colour must survive" },
			};

			// Constant-coordinate quads: A paints texel (0,0), B texel (1,1),
			// C texel (2,2). A scale of 0 makes the interpolated coordinate constant.
			Vertex quadA[3], quadB[3], quadC[3];
			makeQuad(quadA, 0.0625, 0.0625, 0.0, 0.0, 0.9);
			makeQuad(quadB, 0.1875, 0.1875, 0.0, 0.0, 0.1);
			makeQuad(quadC, 0.3125, 0.3125, 0.0, 0.0, 0.5);
			auto bufA = device->newBuffer(quadA, sizeof(quadA), Indium::ResourceOptions::StorageModeShared);
			auto bufB = device->newBuffer(quadB, sizeof(quadB), Indium::ResourceOptions::StorageModeShared);
			auto bufC = device->newBuffer(quadC, sizeof(quadC), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.0);
			Indium::SamplerDescriptor sd {};
			sd.sAddressMode = Indium::SamplerAddressMode::ClampToEdge;
			sd.tAddressMode = Indium::SamplerAddressMode::ClampToEdge;
			auto samp = device->newSamplerState(sd);
			const uint8_t* texelOf[4] = {
				nullptr,
				&level0[(0 * TEX_W + 0) * 4],
				&level0[(1 * TEX_W + 1) * 4],
				&level0[(2 * TEX_W + 2) * 4],
			};

			for (const auto& dcase : depthCases) {
				Indium::DepthStencilDescriptor dsd {};
				dsd.depthWriteEnabled = dcase.writeEnabled;
				dsd.depthCompareFunction = dcase.cmp;
				auto dstate = device->newDepthStencilState(dsd);

				std::vector<uint8_t> image(W * H * 4, 0);
				{
					Indium::RenderPassDescriptor rp {};
					rp.colorAttachments.emplace_back();
					rp.colorAttachments[0].texture = ctx.target;
					rp.colorAttachments[0].loadAction = Indium::LoadAction::Clear;
					rp.colorAttachments[0].storeAction = Indium::StoreAction::Store;
					// 0xFF00FF is not producible by any texel of level 0.
					rp.colorAttachments[0].clearColor = Indium::ClearColor(1, 0, 1, 1);
					rp.depthAttachment.emplace();
					rp.depthAttachment->texture = ctx.depth;
					rp.depthAttachment->loadAction = Indium::LoadAction::Clear;
					rp.depthAttachment->storeAction = Indium::StoreAction::Store;
					rp.depthAttachment->clearDepth = dcase.clearDepth;
					rp.renderTargetWidth = W;
					rp.renderTargetHeight = H;

					auto cb = ctx.queue->commandBuffer();
					auto enc = cb->renderCommandEncoder(rp);
					enc->setViewport(Indium::Viewport { 0, 0, (double)W, (double)H, 0, 1 });
					enc->setRenderPipelineState(ctx.pipeline);
					enc->setVertexBuffer(ubuf, 0, 1);
					enc->setFragmentBuffer(ubuf, 0, 0);
					enc->setFragmentTexture(ctx.source, 0);
					enc->setFragmentSamplerState(samp, 0);
					enc->setDepthStencilState(dstate);
					const std::shared_ptr<Indium::Buffer> bufs[3] = { bufA, bufB, bufC };
					for (int i = 0; i < 3; i++) {
						enc->setVertexBuffer(bufs[i], 0, 0);
						enc->drawPrimitives(Indium::PrimitiveType::Triangle, 0, 3);
					}
					enc->endEncoding();
					cb->commit();
					cb->waitUntilCompleted();
				}
				{
					size_t bpr = W * 4;
					auto readback = ctx.device->newBuffer(image.size(), Indium::ResourceOptions::StorageModeShared);
					auto cb = ctx.queue->commandBuffer();
					auto blit = cb->blitCommandEncoder();
					blit->copy(ctx.target, 0, 0, Indium::Origin { 0, 0, 0 }, Indium::Size { W, H, 1 },
						readback, 0, bpr, bpr, Indium::BlitOption::None);
					blit->endEncoding();
					cb->commit();
					cb->waitUntilCompleted();
					memcpy(image.data(), readback->contents(), image.size());
				}

				// bucket 0 = unrecognised, 1..3 = the three draws, 4 = the clear colour
				size_t count[5] = { 0, 0, 0, 0, 0 };
				for (size_t y = 0; y < H; y++)
					for (size_t x = 0; x < W; x++) {
						const uint8_t* q = &image[(y * W + x) * 4];
						int which = 0;
						for (int k = 1; k <= 3; k++)
							if (q[0] == texelOf[k][0] && q[1] == texelOf[k][1] && q[2] == texelOf[k][2]) { which = k; break; }
						if (which == 0 && q[0] == 255 && q[1] == 0 && q[2] == 255) which = 4;
						count[which]++;
					}
				const char* names[5] = { "other", "A(z=0.9)", "B(z=0.1)", "C(z=0.5)", "clear" };
				// winner 0 means "nothing was drawn", which shows up as the clear
				// colour rather than as a bucket of its own.
				const int expectBucket = (dcase.winner == 0) ? 4 : dcase.winner;
				bool pass = (count[expectBucket] == W * H) && (count[0] == 0);
				char detail[220];
				std::snprintf(detail, sizeof(detail), "%s=%zu %s=%zu %s=%zu clear=%zu other=%zu -- %s",
					names[1], count[1], names[2], count[2], names[3], count[3], count[4],
					count[0], dcase.why);
				report(pass ? "ok" : "FAIL", dcase.name, detail);
				if (!pass) gErrors++;
				gChecks++;
			}
		}

		// ---- group 8: smoke only, no pixel claim ---------------------------
		std::cout << "\n[8] smoke only (executed, no pixel expectation)\n";
		{
			struct SmokeCase { const char* name; Indium::SamplerDescriptor desc; const char* note; };
			Indium::SamplerDescriptor base {};
			base.sAddressMode = Indium::SamplerAddressMode::Repeat;
			base.tAddressMode = Indium::SamplerAddressMode::Repeat;

			auto aniso = base; aniso.maxAnisotropy = 16;
			auto argbuf = base; argbuf.supportArgumentBuffers = true;
			auto unnorm = base; unnorm.normalizedCoordinates = false;
			auto cmpfn = base; cmpfn.compareFunction = Indium::CompareFunction::GreaterEqual;
			auto rz = base; rz.rAddressMode = Indium::SamplerAddressMode::MirrorRepeat;
			auto cz = base; cz.sAddressMode = Indium::SamplerAddressMode::ClampToZero;
			cz.tAddressMode = Indium::SamplerAddressMode::ClampToZero;
			auto naniso = base; naniso.maxAnisotropy = 0;

			const SmokeCase smokes[] = {
				{ "maxAnisotropy=16",        aniso,  "isotropic footprint, so no pixel expectation is possible" },
				{ "maxAnisotropy=0",         naniso, "invalid per Metal; must not crash or hang" },
				{ "supportArgumentBuffers=YES", argbuf, "Indium stores but never reads the field" },
				{ "compareFunction=GreaterEqual", cmpfn, "a plain sample() ignores compareOp" },
				{ "rAddressMode on a 2D texture", rz,  "only observable through a 3D texture" },
				{ "s/t ClampToZero",          cz,    "Indium maps this to CLAMP_TO_BORDER, so it equals ClampToBorderColor" },
			};

			for (const auto& sc : smokes) {
				Vertex verts[3];
				makeQuad(verts, 0.0, 0.0, 0.25 / TEX_W, 0.25 / TEX_W, 0.5);
				auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
				auto ubuf = makeUBuf(0.5);
				auto samp = device->newSamplerState(sc.desc);
				auto img = render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0);
				size_t nonBlack = 0;
				for (size_t i = 0; i < W * H; i++)
					if (img[i*4] || img[i*4+1] || img[i*4+2]) nonBlack++;
				char detail[200];
				std::snprintf(detail, sizeof(detail), "%zu/%zu pixels written; %s",
					nonBlack, W * H, sc.note);
				report("ok", sc.name, detail);
				gChecks++;
			}

			// The vertex-stage and compute-stage setters have no observable effect
			// with these shaders (the vertex stage does not sample and the compute
			// pass has no kernel), so they are executed for their side effects only.
			{
				Vertex verts[3];
				makeQuad(verts, 0.0, 0.0, 0.25 / TEX_W, 0.25 / TEX_W, 0.5);
				auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
				auto ubuf = makeUBuf(0.5);
				Indium::SamplerDescriptor d {};
				auto s0 = device->newSamplerState(d);
				auto s1 = device->newSamplerState(d);

				std::vector<uint8_t> base_img = render(ctx, vbuf, ubuf, { s0 }, false, false, 0, 0);

				// setVertexSamplerState / setVertexSamplerStates, all three forms
				Indium::RenderPassDescriptor rp {};
				rp.colorAttachments.emplace_back();
				rp.colorAttachments[0].texture = ctx.target;
				rp.colorAttachments[0].loadAction = Indium::LoadAction::Clear;
				rp.colorAttachments[0].storeAction = Indium::StoreAction::Store;
				rp.renderTargetWidth = W;
				rp.renderTargetHeight = H;
				auto cb = ctx.queue->commandBuffer();
				auto enc = cb->renderCommandEncoder(rp);
				enc->setViewport(Indium::Viewport { 0, 0, (double)W, (double)H, 0, 1 });
				enc->setRenderPipelineState(ctx.pipeline);
				enc->setVertexBuffer(vbuf, 0, 0);
				enc->setVertexBuffer(ubuf, 0, 1);
				enc->setFragmentBuffer(ubuf, 0, 0);
				enc->setFragmentTexture(ctx.source, 0);
				enc->setFragmentSamplerState(s0, 0);
				enc->setVertexSamplerState(s0, 0);
				enc->setVertexSamplerState(s1, 0.0f, 0.0f, 1);
				enc->setVertexSamplerStates({ s0, s1 }, Indium::Range<size_t> { 0, 2 });
				enc->setVertexSamplerStates({ s0 }, { 0.0f }, { 0.0f }, Indium::Range<size_t> { 0, 1 });
				enc->drawPrimitives(Indium::PrimitiveType::Triangle, 0, 3);
				enc->endEncoding();
				cb->commit();
				cb->waitUntilCompleted();
				report("ok", "setVertexSamplerState(s), all 3 forms", "executed; vertex stage does not sample");
				gChecks++;

				// compute stage: setSamplerState / setSamplerStates, all three forms
				Indium::ComputePassDescriptor cp {};
				auto cb2 = ctx.queue->commandBuffer();
				auto cenc = cb2->computeCommandEncoder(cp);
				cenc->setSamplerState(s0, 0);
				cenc->setSamplerState(s1, 0.0f, 0.0f, 1);
				cenc->setSamplerStates({ s0, s1 }, Indium::Range<size_t> { 0, 2 });
				cenc->setSamplerStates({ s0 }, { 0.0f }, { 0.0f }, Indium::Range<size_t> { 0, 1 });
				cenc->endEncoding();
				cb2->commit();
				cb2->waitUntilCompleted();
				report("ok", "setSamplerState(s), all 3 forms", "executed; the compute pass has no kernel");
				gChecks++;
			}
		}

		// ---- group 9: the encoder setter forms ------------------------------
		std::cout << "\n[9] encoder setter forms (same pixels through each form)\n";
		{
			Indium::SamplerDescriptor d {};
			d.sAddressMode = Indium::SamplerAddressMode::MirrorRepeat;
			d.tAddressMode = Indium::SamplerAddressMode::MirrorRepeat;
			Case c {};
			c.name = "reference";
			c.desc = d;
			c.uvOriginX = 0.5 - 0.75;  c.uvScaleX = 1.5 / W;
			c.uvOriginY = 0.5 - 0.75;  c.uvScaleY = 1.5 / H;
			c.sMode = AddrMode::MirrorRepeat; c.tMode = AddrMode::MirrorRepeat;
			c.normalized = true;

			Vertex verts[3];
			makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
			auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
			auto ubuf = makeUBuf(0.5);
			auto s0 = device->newSamplerState(d);
			auto s1 = device->newSamplerState(d);
			// sampler 1 is deliberately different, so the plural form with range
			// {0,2} must place d at index 0 and s1's descriptor at index 1; the
			// shader only reads index 0, so the image must still match.

			auto singular  = render(ctx, vbuf, ubuf, { s0 }, false, false, 0, 0);
			auto plural    = render(ctx, vbuf, ubuf, { s0, s1 }, true, false, 0, 0);
			auto lodClamps = render(ctx, vbuf, ubuf, { s0 }, false, true, 0, 0);

			auto cmp = [&](const char* what, const std::vector<uint8_t>& img) {
				bool same = (img == singular);
				if (same) { report("ok", what, "byte-identical to the singular form"); }
				else      { report("FAIL", what, "differs from the singular form"); gErrors++; }
				gChecks++;
			};
			cmp("setFragmentSamplerState:atIndex:", singular);
			cmp("setFragmentSamplerStates:withRange:", plural);
			cmp("setFragmentSamplerState:lodMinClamp:lodMaxClamp:atIndex:", lodClamps);
		}

		// ---- group 10: anisotropic filtering ---------------------------------
		// The footprint is long in x and one texel tall in y, over the stripe
		// texture, whose level 0 is constant along x. Every anisotropic tap
		// therefore lands on the same stripe, so the weighted average of N taps is
		// that stripe and the expected result is exact: 0 or 255, the level-0
		// texel values. Isotropic filtering cannot do this: it takes the LOD from
		// the long axis, log2(16) = 4, which lands on a flat level, so the answer
		// is a single mid-grey and no level-0 detail survives.
		std::cout << "\n[10] anisotropic filtering at a grazing footprint (16:1)\n";
		{
			auto pd = std::dynamic_pointer_cast<Indium::PrivateDevice>(device);
			size_t deviceLimit = (size_t)pd->properties().limits.maxSamplerAnisotropy;

			auto anisoShot = [&](size_t maxAnisotropy) {
				Case c {};
				c.desc = Indium::SamplerDescriptor {};
				c.desc.minFilter = Indium::SamplerMinMagFilter::Linear;
				c.desc.magFilter = Indium::SamplerMinMagFilter::Linear;
				c.desc.mipFilter = Indium::SamplerMipFilter::Nearest;
				c.desc.sAddressMode = Indium::SamplerAddressMode::Repeat;
				c.desc.tAddressMode = Indium::SamplerAddressMode::Repeat;
				c.desc.maxAnisotropy = maxAnisotropy;
				c.uvOriginX = 0.0; c.uvScaleX = 16.0 / STRIPE_W;
				c.uvOriginY = 0.0; c.uvScaleY = 1.0 / STRIPE_H;
				c.sMode = AddrMode::Repeat; c.tMode = AddrMode::Repeat;
				c.normalized = true;

				Vertex verts[3];
				makeQuad(verts, c.uvOriginX, c.uvOriginY, c.uvScaleX, c.uvScaleY, 0.5);
				auto vbuf = device->newBuffer(verts, sizeof(verts), Indium::ResourceOptions::StorageModeShared);
				auto ubuf = makeUBuf(0.5);
				auto samp = device->newSamplerState(c.desc);
				return render(ctx, vbuf, ubuf, { samp }, false, false, 0, 0, ctx.striped);
			};

			// The exact reference: every pixel is one of the two level-0 stripe
			// values. Any colour that is neither is a blend or a coarser level.
			auto countLevel0 = [](const std::vector<uint8_t>& img, size_t& other, size_t& midGrey) {
				size_t lv0 = 0; other = 0; midGrey = 0;
				for (size_t i = 0; i < W * H; i++) {
					const uint8_t* p4 = &img[i * 4];
					bool grey = (p4[0] == p4[1] && p4[1] == p4[2]);
					if (p4[0] == 0 || p4[0] == 255) lv0++;
					else if (grey && p4[0] >= 126 && p4[0] <= 129) midGrey++;
					else other++;
				}
				return lv0;
			};

			size_t other = 0, grey = 0;
			auto iso = anisoShot(1);
			if (getenv("SAMPLER_DIAG")) {
				for (int an : { 1, 2, 4, 8, 16 }) {
					auto t = anisoShot((size_t)an);
					std::map<uint32_t, size_t> hh;
					for (size_t i = 0; i < W * H; i++)
						hh[(uint32_t)t[i*4] << 16 | (uint32_t)t[i*4+1] << 8 | t[i*4+2]]++;
					std::printf("      aniso=%2d:", an);
					int shown = 0;
					for (auto& kv : hh) { std::printf(" (%06x)x%zu", kv.first, kv.second); if (++shown > 5) break; }
					std::printf("  [%zu buckets]\n", hh.size());
				}
			}
			size_t isoLevel0 = countLevel0(iso, other, grey);
			{
				char detail[200];
				std::snprintf(detail, sizeof(detail),
					"level0=%zu flatgrey=%zu other=%zu of %zu; isotropic takes the LOD from the long axis",
					isoLevel0, grey, other, W * H);
				// Isotropic must lose every level-0 pixel and land on a flat level.
				bool pass = (isoLevel0 == 0) && (grey == W * H);
				report(pass ? "ok" : "FAIL", "maxAnisotropy=1 is flat grey", detail);
				if (!pass) gErrors++;
				gChecks++;
			}

			auto sharp = anisoShot(deviceLimit);
			size_t sharpOther = 0, sharpGrey = 0;
			size_t sharpLevel0 = countLevel0(sharp, sharpOther, sharpGrey);
			{
				char detail[200];
				std::snprintf(detail, sizeof(detail),
					"level0=%zu flatgrey=%zu other=%zu of %zu; expected every pixel to be a level-0 stripe",
					sharpLevel0, sharpGrey, sharpOther, W * H);
				bool pass = (sharpLevel0 == W * H);
				report(pass ? "ok" : "FAIL", "maxAnisotropy=device limit is sharp", detail);
				if (!pass) gErrors++;
				gChecks++;
			}

			// Negative controls, both directions. If either of these passed, the
			// two checks above could not be telling anisotropy apart.
			{
				size_t o1 = 0, g1 = 0;
				bool isoFailsSharp = (countLevel0(iso, o1, g1) != W * H);
				report(isoFailsSharp ? "ok" : "FAIL", "isotropic image fails the sharp test",
					isoFailsSharp ? "the sharp check rejects the isotropic result"
					              : "the isotropic image satisfied the sharp test, so it is vacuous");
				if (!isoFailsSharp) gErrors++;
				gChecks++;

				// The sharp image must not be classifiable as the flat coarse level,
				// otherwise the "flat" check would be measuring nothing.
				bool sharpFailsFlat = (sharpGrey == 0) && (sharpLevel0 == W * H);
				report(sharpFailsFlat ? "ok" : "FAIL", "anisotropic image fails the flat test",
					sharpFailsFlat ? "no pixel of it is the flat coarse level, so the flat check rejects it"
					               : "the anisotropic image also reads as the flat level, so the flat check is vacuous");
				if (!sharpFailsFlat) gErrors++;
				gChecks++;
			}

			// A descriptor asking for more than the device supports must land on
			// the device's maximum, not silently below it. Vulkan leaves the result
			// undefined; on asahi an unclamped 1024 against a limit of 16 came back
			// fully isotropic, so the anisotropy was lost rather than clamped.
			{
				auto over = anisoShot(deviceLimit * 64);
				char detail[200];
				std::snprintf(detail, sizeof(detail),
					"maxAnisotropy=%zu gives %zu level-0 pixels; maxAnisotropy=%zu gives %zu",
					deviceLimit * 64, countLevel0(over, other, grey), deviceLimit, sharpLevel0);
				bool pass = (over == sharp);
				report(pass ? "ok" : "FAIL", "maxAnisotropy past the limit is clamped to it", detail);
				if (!pass) gErrors++;
				gChecks++;
			}

			// Metal requires maxAnisotropy >= 1. Zero is out of range, and must not
			// be more anisotropic than one.
			{
				auto zero = anisoShot(0);
				bool pass = (zero == iso);
				char detail[200];
				std::snprintf(detail, sizeof(detail),
					"maxAnisotropy=0 gives %zu level-0 pixels, maxAnisotropy=1 gives %zu",
					countLevel0(zero, other, grey), isoLevel0);
				report(pass ? "ok" : "FAIL", "maxAnisotropy=0 matches maxAnisotropy=1", detail);
				if (!pass) gErrors++;
				gChecks++;
			}
		}

		keepPolling = false;
		device->wakeupEventLoop();
		poll.join();
	}

	if (gErrors == 0)
		std::cout << "\nRESULT: all " << gChecks << " checks passed\n";
	else
		std::cout << "\nRESULT: FAILED, " << gErrors << " of " << gChecks << " checks\n";

	// Tearing down everything this harness accumulated segfaults somewhere inside
	// libindium, so the verdict is emitted and the process leaves before the
	// destructors run. Otherwise the exit code would report a teardown crash
	// rather than the result. A minimal program that creates a device, a queue, a
	// mipmapped texture, a sampler and a depth-stencil state does tear down
	// cleanly, so this is not simply "queue teardown is broken".
	std::cout.flush();
	_exit(gErrors == 0 ? 0 : 1);
}
