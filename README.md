# zig-jpegli

Zig build system for [Google's jpegli](https://github.com/google/jpegli) - a high-quality JPEG encoder/decoder library that is API-compatible with libjpeg.

> NOTE: This project is heavily AI / LLM driven. Please take the time, read and verify the build.zig file to ensure correctness yourself.

## Features

- **libjpeg API compatible** - Drop-in replacement for libjpeg/libjpeg-turbo
- **Full SIMD support** - Uses [Google Highway](https://github.com/google/highway) for portable SIMD
- **CLI tools included** - `cjpegli` (encoder) and `djpegli` (decoder)
- **Cross-platform** - Builds with Zig's cross-compilation support

## Building

```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseFast

# Cross-compile example
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
```

## Output

- `zig-out/lib/libjpegli.a` - Static library
- `zig-out/lib/libhwy.a` - Highway SIMD library
- `zig-out/bin/cjpegli` - JPEG encoder CLI
- `zig-out/bin/djpegli` - JPEG decoder CLI
- `zig-out/include/` - libjpeg-compatible headers (`jpeglib.h`, `jconfig.h`, `jmorecfg.h`, `jerror.h`)

## CLI Usage

```bash
# Encode PNG/PPM to JPEG
cjpegli input.png output.jpg -q 90

# Decode JPEG to PNG/PPM
djpegli input.jpg output.png
```

## Dependencies

All dependencies are fetched automatically via Zig's package manager:

| Dependency | Source | License |
|------------|--------|---------|
| jpegli | [github.com/google/jpegli](https://github.com/google/jpegli) | BSD-3-Clause |
| highway | [github.com/google/highway](https://github.com/google/highway) | Apache-2.0 |
| libjpeg-turbo | [github.com/libjpeg-turbo/libjpeg-turbo](https://github.com/libjpeg-turbo/libjpeg-turbo) | IJG/BSD/zlib |
| libpng | [github.com/allyourcodebase/libpng](https://github.com/allyourcodebase/libpng) | libpng/zlib |

### skcms (vendored)

[skcms](https://skia.googlesource.com/skcms) is vendored via git subtree because Zig's package fetcher doesn't support `googlesource.com`:

```bash
# Initial import (already done)
git subtree add --prefix=skcms https://skia.googlesource.com/skcms bf2d52b98a420c59d991ced59fef8b4243b7dc13 --squash

# To update skcms
git subtree pull --prefix=skcms https://skia.googlesource.com/skcms <new-commit> --squash
```

## Upstream References

When updating this build, check these upstream CMake files for source list changes:

- [lib/jxl_lists.cmake](https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jxl_lists.cmake) - Source file lists
- [lib/jpegli.cmake](https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/lib/jpegli.cmake) - jpegli build definition
- [tools/CMakeLists.txt](https://github.com/google/jpegli/blob/bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a/tools/CMakeLists.txt) - CLI tools
- [highway CMakeLists.txt](https://github.com/google/highway/blob/457c891775a7397bdb0376bb1031e6e027af1c48/CMakeLists.txt#L356-L367) - Highway sources
- [skcms BUILD.bazel](https://skia.googlesource.com/skcms/+/bf2d52b98a420c59d991ced59fef8b4243b7dc13/BUILD.bazel#11) - skcms sources

## License

See [LICENSE.md](LICENSE.md) for full license information.

- Build scripts (`build.zig`, `build.zig.zon`, `jconfig.h`): MIT
- Vendored and referenced source code: See individual sections in LICENSE.md

