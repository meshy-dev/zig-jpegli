//! Zig build for Google's jpegli - a JPEG encoder/decoder library
//!
//! This build file is derived from the upstream CMake build system.
//! When updating to newer versions, check the links in comments for source list changes:

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Upstream dependencies
    const upstream = b.dependency("jpegli", .{});
    const highway = b.dependency("highway", .{});
    const libjpeg_turbo = b.dependency("libjpeg_turbo", .{});
    const png_dep = b.dependency("libpng", .{ .target = target, .optimize = optimize });

    // ============== Internal libraries (not installed, used transitively) ==============

    // Highway SIMD library (internal)
    // Source: https://github.com/google/highway/blob/457c891775a7397bdb0376bb1031e6e027af1c48/CMakeLists.txt#L356-L367
    const hwy_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    hwy_mod.addIncludePath(highway.path(""));
    hwy_mod.addCSourceFiles(.{
        .root = highway.path(""),
        .files = hwy_sources,
        .flags = cxx_flags,
    });
    hwy_mod.addCMacro("HWY_STATIC_DEFINE", "1");

    const hwy = b.addLibrary(.{
        .name = "hwy",
        .linkage = .static,
        .root_module = hwy_mod,
    });

    // skcms color management library (internal)
    // Vendored via git subtree from: https://skia.googlesource.com/skcms/+/bf2d52b98a420c59d991ced59fef8b4243b7dc13
    // Source list: https://skia.googlesource.com/skcms/+/bf2d52b98a420c59d991ced59fef8b4243b7dc13/BUILD.bazel#11
    const skcms_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    skcms_mod.addIncludePath(b.path("skcms"));
    skcms_mod.addCSourceFiles(.{
        .root = b.path("skcms"),
        .files = skcms_sources,
        .flags = cxx_flags,
    });

    const skcms = b.addLibrary(.{
        .name = "skcms",
        .linkage = .static,
        .root_module = skcms_mod,
    });

    // ============== Jpegli static library (the only public artifact) ==============
    // Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jpegli.cmake
    const jpegli_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    jpegli_mod.addIncludePath(upstream.path(""));
    jpegli_mod.addIncludePath(highway.path(""));
    jpegli_mod.addIncludePath(libjpeg_turbo.path(""));
    jpegli_mod.addIncludePath(b.path("")); // for jconfig.h
    jpegli_mod.addCMacro("HWY_STATIC_DEFINE", "1");
    jpegli_mod.addCSourceFiles(.{
        .root = upstream.path("lib"),
        .files = jpegli_sources,
        .flags = cxx_flags,
    });
    jpegli_mod.linkLibrary(hwy);

    const jpegli = b.addLibrary(.{
        .name = "jpegli",
        .linkage = .static,
        .root_module = jpegli_mod,
    });

    // Install only the jpegli library
    b.installArtifact(jpegli);

    // Install libjpeg-compatible headers (for libjpeg API compatibility)
    // Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jpegli.cmake#L72-L77
    jpegli.installHeader(b.path("jconfig.h"), "jconfig.h");
    jpegli.installHeader(libjpeg_turbo.path("jpeglib.h"), "jpeglib.h");
    jpegli.installHeader(libjpeg_turbo.path("jmorecfg.h"), "jmorecfg.h");
    jpegli.installHeader(libjpeg_turbo.path("jerror.h"), "jerror.h");

    // Install jpegli-specific headers (for direct jpegli API usage)
    jpegli.installHeader(upstream.path("lib/jpegli/common.h"), "jpegli/common.h");
    jpegli.installHeader(upstream.path("lib/jpegli/decode.h"), "jpegli/decode.h");
    jpegli.installHeader(upstream.path("lib/jpegli/encode.h"), "jpegli/encode.h");
    jpegli.installHeader(upstream.path("lib/jpegli/types.h"), "jpegli/types.h");

    // ============== CLI tool internal libraries (not installed) ==============

    // Extras library for CLI tools (internal)
    // Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake#L96-L131
    const jxl_extras_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    jxl_extras_mod.addIncludePath(upstream.path(""));
    jxl_extras_mod.addIncludePath(highway.path(""));
    jxl_extras_mod.addIncludePath(libjpeg_turbo.path(""));
    jxl_extras_mod.addIncludePath(b.path(""));
    jxl_extras_mod.addIncludePath(b.path("skcms"));
    jxl_extras_mod.addIncludePath(png_dep.path(""));
    jxl_extras_mod.addCMacro("HWY_STATIC_DEFINE", "1");
    jxl_extras_mod.addCMacro("JPEGXL_ENABLE_APNG", "1");
    // Disable optional codecs that require external libraries (giflib, openexr, libjpeg)
    jxl_extras_mod.addCMacro("JPEGXL_ENABLE_EXR", "0");
    jxl_extras_mod.addCMacro("JPEGXL_ENABLE_GIF", "0");
    jxl_extras_mod.addCMacro("JPEGXL_ENABLE_JPEG", "0");
    jxl_extras_mod.addCMacro("JPEGXL_ENABLE_JPEGLI", "1");
    jxl_extras_mod.addCMacro("JPEGXL_ENABLE_SKCMS", "1");
    jxl_extras_mod.addCSourceFiles(.{
        .root = upstream.path("lib"),
        .files = extras_sources,
        .flags = cxx_flags,
    });
    // APNG codec from third_party/apngdis
    jxl_extras_mod.addCSourceFiles(.{
        .root = upstream.path("third_party/apngdis"),
        .files = &.{ "dec.cc", "enc.cc" },
        .flags = cxx_flags,
    });
    jxl_extras_mod.linkLibrary(hwy);
    jxl_extras_mod.linkLibrary(jpegli);
    jxl_extras_mod.linkLibrary(skcms);
    jxl_extras_mod.linkLibrary(png_dep.artifact("png"));

    const jxl_extras = b.addLibrary(.{
        .name = "jxl_extras",
        .linkage = .static,
        .root_module = jxl_extras_mod,
    });

    // Threads library (internal)
    // Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake#L240-L245
    const jxl_threads_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    jxl_threads_mod.addIncludePath(upstream.path(""));
    jxl_threads_mod.addIncludePath(highway.path(""));
    jxl_threads_mod.addCMacro("HWY_STATIC_DEFINE", "1");
    jxl_threads_mod.addCSourceFiles(.{
        .root = upstream.path("lib"),
        .files = threads_sources,
        .flags = cxx_flags,
    });

    const jxl_threads = b.addLibrary(.{
        .name = "jxl_threads",
        .linkage = .static,
        .root_module = jxl_threads_mod,
    });

    // CMS library (internal)
    // Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake#L79-L89
    const jxl_cms_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    jxl_cms_mod.addIncludePath(upstream.path(""));
    jxl_cms_mod.addIncludePath(highway.path(""));
    jxl_cms_mod.addIncludePath(b.path("skcms"));
    jxl_cms_mod.addCMacro("HWY_STATIC_DEFINE", "1");
    jxl_cms_mod.addCMacro("JPEGXL_ENABLE_SKCMS", "1");
    jxl_cms_mod.addCSourceFiles(.{
        .root = upstream.path("lib"),
        .files = cms_sources,
        .flags = cxx_flags,
    });
    jxl_cms_mod.linkLibrary(hwy);
    jxl_cms_mod.linkLibrary(skcms);

    const jxl_cms = b.addLibrary(.{
        .name = "jxl_cms",
        .linkage = .static,
        .root_module = jxl_cms_mod,
    });

    // ============== cjpegli encoder tool ==============
    // Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/tools/CMakeLists.txt#L77-L79
    const cjpegli_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    cjpegli_mod.addIncludePath(upstream.path(""));
    cjpegli_mod.addIncludePath(highway.path(""));
    cjpegli_mod.addIncludePath(libjpeg_turbo.path(""));
    cjpegli_mod.addIncludePath(b.path(""));
    cjpegli_mod.addIncludePath(b.path("skcms"));
    cjpegli_mod.addIncludePath(png_dep.path(""));
    cjpegli_mod.addCMacro("HWY_STATIC_DEFINE", "1");
    cjpegli_mod.addCMacro("JPEGXL_VERSION", "\"0.11.1\"");
    cjpegli_mod.addCMacro("JPEGXL_ENABLE_APNG", "1");
    cjpegli_mod.addCMacro("JPEGXL_ENABLE_EXR", "0");
    cjpegli_mod.addCMacro("JPEGXL_ENABLE_GIF", "0");
    cjpegli_mod.addCMacro("JPEGXL_ENABLE_JPEG", "0");
    cjpegli_mod.addCMacro("JPEGXL_ENABLE_JPEGLI", "1");
    cjpegli_mod.addCMacro("JPEGXL_ENABLE_SKCMS", "1");
    cjpegli_mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = tool_sources,
        .flags = cxx_flags,
    });
    cjpegli_mod.addCSourceFiles(.{
        .root = upstream.path("tools"),
        .files = &.{"cjpegli.cc"},
        .flags = cxx_flags,
    });
    // Link against jpegli (the public artifact) and internal libraries
    cjpegli_mod.linkLibrary(jpegli);
    cjpegli_mod.linkLibrary(jxl_extras);
    cjpegli_mod.linkLibrary(jxl_threads);
    cjpegli_mod.linkLibrary(jxl_cms);
    cjpegli_mod.linkLibrary(hwy);
    cjpegli_mod.linkLibrary(skcms);
    cjpegli_mod.linkLibrary(png_dep.artifact("png"));

    const cjpegli = b.addExecutable(.{
        .name = "cjpegli",
        .root_module = cjpegli_mod,
    });
    b.installArtifact(cjpegli);

    // ============== djpegli decoder tool ==============
    // Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/tools/CMakeLists.txt#L80-L82
    const djpegli_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    djpegli_mod.addIncludePath(upstream.path(""));
    djpegli_mod.addIncludePath(highway.path(""));
    djpegli_mod.addIncludePath(libjpeg_turbo.path(""));
    djpegli_mod.addIncludePath(b.path(""));
    djpegli_mod.addIncludePath(b.path("skcms"));
    djpegli_mod.addIncludePath(png_dep.path(""));
    djpegli_mod.addCMacro("HWY_STATIC_DEFINE", "1");
    djpegli_mod.addCMacro("JPEGXL_VERSION", "\"0.11.1\"");
    djpegli_mod.addCMacro("JPEGXL_ENABLE_APNG", "1");
    djpegli_mod.addCMacro("JPEGXL_ENABLE_EXR", "0");
    djpegli_mod.addCMacro("JPEGXL_ENABLE_GIF", "0");
    djpegli_mod.addCMacro("JPEGXL_ENABLE_JPEG", "0");
    djpegli_mod.addCMacro("JPEGXL_ENABLE_JPEGLI", "1");
    djpegli_mod.addCMacro("JPEGXL_ENABLE_SKCMS", "1");
    djpegli_mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = tool_sources,
        .flags = cxx_flags,
    });
    djpegli_mod.addCSourceFiles(.{
        .root = upstream.path("tools"),
        .files = &.{"djpegli.cc"},
        .flags = cxx_flags,
    });
    // Link against jpegli (the public artifact) and internal libraries
    djpegli_mod.linkLibrary(jpegli);
    djpegli_mod.linkLibrary(jxl_extras);
    djpegli_mod.linkLibrary(jxl_threads);
    djpegli_mod.linkLibrary(jxl_cms);
    djpegli_mod.linkLibrary(hwy);
    djpegli_mod.linkLibrary(skcms);
    djpegli_mod.linkLibrary(png_dep.artifact("png"));

    const djpegli = b.addExecutable(.{
        .name = "djpegli",
        .root_module = djpegli_mod,
    });
    b.installArtifact(djpegli);
}

const cxx_flags: []const []const u8 = &.{
    "-std=c++17",
    "-fPIC",
    "-fno-exceptions",
    "-fno-rtti",
    "-Wall",
    "-Wno-builtin-macro-redefined",
    "-D__DATE__=\"redacted\"",
    "-D__TIMESTAMP__=\"redacted\"",
    "-D__TIME__=\"redacted\"",
};

// Highway SIMD library sources
// Source: https://github.com/google/highway/blob/457c891775a7397bdb0376bb1031e6e027af1c48/CMakeLists.txt#L356-L367
const hwy_sources: []const []const u8 = &.{
    "hwy/abort.cc",
    "hwy/aligned_allocator.cc",
    "hwy/nanobenchmark.cc",
    "hwy/per_target.cc",
    "hwy/print.cc",
    "hwy/targets.cc",
    "hwy/timer.cc",
};

// skcms color management sources
// Source: https://skia.googlesource.com/skcms/+/bf2d52b98a420c59d991ced59fef8b4243b7dc13/BUILD.bazel#11
const skcms_sources: []const []const u8 = &.{
    "skcms.cc",
    "src/skcms_TransformBaseline.cc",
    "src/skcms_TransformHsw.cc",
    "src/skcms_TransformSkx.cc",
};

// Jpegli core library sources (JPEGXL_INTERNAL_JPEGLI_SOURCES)
// Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake#L133-L180
const jpegli_sources: []const []const u8 = &.{
    "jpegli/adaptive_quantization.cc",
    "jpegli/bit_writer.cc",
    "jpegli/bitstream.cc",
    "jpegli/color_quantize.cc",
    "jpegli/color_transform.cc",
    "jpegli/common.cc",
    "jpegli/decode.cc",
    "jpegli/decode_marker.cc",
    "jpegli/decode_scan.cc",
    "jpegli/destination_manager.cc",
    "jpegli/downsample.cc",
    "jpegli/encode.cc",
    "jpegli/encode_finish.cc",
    "jpegli/encode_streaming.cc",
    "jpegli/entropy_coding.cc",
    "jpegli/error.cc",
    "jpegli/huffman.cc",
    "jpegli/idct.cc",
    "jpegli/input.cc",
    "jpegli/memory_manager.cc",
    "jpegli/quant.cc",
    "jpegli/render.cc",
    "jpegli/simd.cc",
    "jpegli/source_manager.cc",
    "jpegli/upsample.cc",
};

// Extras library sources (JPEGXL_INTERNAL_EXTRAS_SOURCES + codecs)
// Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake#L96-L131
// Codec sources: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake#L182-L230
const extras_sources: []const []const u8 = &.{
    // Core extras (JPEGXL_INTERNAL_EXTRAS_SOURCES)
    "extras/alpha_blend.cc",
    "extras/butteraugli.cc",
    "extras/convolve_separable5.cc",
    "extras/convolve_slow.cc",
    "extras/exif.cc",
    "extras/image.cc",
    "extras/image_color_transform.cc",
    "extras/memory_manager_internal.cc",
    "extras/mmap.cc",
    "extras/simd_util.cc",
    "extras/time.cc",
    "extras/xyb_transform.cc",
    // Decoders
    "extras/dec/color_description.cc",
    "extras/dec/color_hints.cc",
    "extras/dec/decode.cc",
    "extras/dec/exr.cc", // Stub via JPEGXL_ENABLE_EXR=0
    "extras/dec/gif.cc", // Stub via JPEGXL_ENABLE_GIF=0
    "extras/dec/jpg.cc", // Stub via JPEGXL_ENABLE_JPEG=0
    "extras/dec/jpegli.cc", // JPEGXL_INTERNAL_CODEC_JPEGLI_SOURCES
    "extras/dec/pgx.cc", // JPEGXL_INTERNAL_CODEC_PGX_SOURCES
    "extras/dec/pnm.cc", // JPEGXL_INTERNAL_CODEC_PNM_SOURCES
    // Encoders
    "extras/enc/encode.cc",
    "extras/enc/exr.cc", // Stub via JPEGXL_ENABLE_EXR=0
    "extras/enc/jpg.cc", // Stub via JPEGXL_ENABLE_JPEG=0
    "extras/enc/jpegli.cc", // JPEGXL_INTERNAL_CODEC_JPEGLI_SOURCES
    "extras/enc/npy.cc",
    "extras/enc/pgx.cc", // JPEGXL_INTERNAL_CODEC_PGX_SOURCES
    "extras/enc/pnm.cc", // JPEGXL_INTERNAL_CODEC_PNM_SOURCES
    // For tools (JPEGXL_INTERNAL_EXTRAS_FOR_TOOLS_SOURCES)
    "extras/metrics.cc",
    "extras/packed_image_convert.cc",
};

// Threads library sources (JPEGXL_INTERNAL_THREADS_SOURCES)
// Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake#L240-L245
const threads_sources: []const []const u8 = &.{
    "threads/thread_parallel_runner.cc",
    "threads/thread_parallel_runner_internal.cc",
};

// CMS library sources (JPEGXL_INTERNAL_CMS_SOURCES)
// Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake#L79-L89
const cms_sources: []const []const u8 = &.{
    "cms/jxl_cms.cc",
};

// Tool helper library sources (jxl_tool in CMakeLists.txt)
// Source: https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/tools/CMakeLists.txt#L12-L17
const tool_sources: []const []const u8 = &.{
    "tools/cmdline.cc",
    "tools/no_memory_manager.cc",
    "tools/speed_stats.cc",
    "tools/tool_version.cc",
    "tools/tracking_memory_manager.cc",
};
