# openssl-cmake

Use OpenSSL in your CMake project without installing it on your system.

A single `FetchContent` block gives you an `OpenSSL::SSL` target on Windows, Linux, and
Android. Libraries are static (`no-shared`), so you don't have to ship OpenSSL DLLs or
shared objects alongside your binary.

- **OpenSSL version**: 3.6.1
- **openssl-cmake version**: 1.2.0

---

## Quick start

```cmake
include(FetchContent)

FetchContent_Declare(
    openssl-cmake
    GIT_REPOSITORY https://github.com/bn3monkey/openssl-cmake.git
    GIT_TAG        v1.2.0
)
FetchContent_MakeAvailable(openssl-cmake)

target_link_libraries(my_app PRIVATE OpenSSL::SSL)
```

That's it. By default this **downloads prebuilt static libraries**, so you pay no OpenSSL
build time.

Linking `OpenSSL::SSL` transitively brings in `OpenSSL::Crypto`, the include directories,
and the platform's system libraries (`ws2_32`/`crypt32` on Windows, `pthread`/`dl` on
Linux). If you only need libcrypto, link `OpenSSL::Crypto` on its own.

---

## Two ways to use this project

There are two paths, and they produce **the same result**. Either way the final targets are
`OpenSSL::SSL` / `OpenSSL::Crypto`, so nothing in your project changes when you switch.

### Method 1 — Prebuilt binaries (default, recommended)

Downloads static libraries published as GitHub Release assets.

```cmake
# No configuration needed — this is the default.
FetchContent_MakeAvailable(openssl-cmake)
```

- **Build time**: a few seconds (download + extract)
- **Disk**: tens of MB in your build directory
- **Requires**: network access at configure time
- **Limitation**: only the combinations in the "Supported platforms" table below

How it works: at configure time CMake detects your OS, architecture, and compiler, builds a
triple (e.g. `windows-x64-msvc-release`), downloads the matching release asset with SHA256
verification, and extracts it to `<build-dir>/prebuilt/<triple>/`. Once downloaded,
re-configuring never touches the network again.

### Method 2 — Build from source

Downloads the OpenSSL source and compiles it in place. This was the v1.0.0 behavior and it
still works exactly as before.

```cmake
set(OPENSSL_CMAKE_USE_PREBUILT OFF CACHE BOOL "" FORCE)   # before FetchContent_MakeAvailable
FetchContent_MakeAvailable(openssl-cmake)
```

Or from the command line:

```bash
cmake -B build -DOPENSSL_CMAKE_USE_PREBUILT=OFF
```

- **Build time**: 10–30 minutes
- **Disk**: hundreds of MB (OpenSSL source + toolchain + object files)
- **Requires**: nothing — Perl, NASM, jom, and MSYS2 are fetched automatically as needed
- **Upside**: works on architectures with no prebuilt, and lets you tweak OpenSSL's
  configure options

**Reach for method 2 when:**

- Your platform isn't in the supported list (macOS, Windows ARM64 MinGW, …)
- You're offline or on a closed network (though see `OPENSSL_CMAKE_PREBUILT_URL` for
  internal mirrors)
- Your Android `minSdk` is below 21
- You need to customize OpenSSL's configure flags

---

## Supported platforms

These are the combinations that ship prebuilt binaries.

| Platform | Architecture | Compiler | Configurations |
|---|---|---|---|
| Windows | x64 | MSVC | Debug + Release |
| Windows | arm64 | MSVC | Debug + Release |
| Windows | x64 | MinGW (MSYS2 MINGW64 / msvcrt) | Release |
| Linux | x64 | GCC / Clang | Release |
| Linux | arm64 | GCC / Clang | Release |
| Android | arm64-v8a | NDK Clang | Release (API 21+) |
| Android | x86_64 | NDK Clang | Release (API 21+) |

Requesting a prebuilt for a combination that isn't listed (Windows ARM64 MinGW, macOS, …)
**fails explicitly at configure time** with the supported list printed. It does not silently
fall back to a source build, so your build will never mysteriously start taking 30 minutes.
Use method 2 in that case.

Source builds additionally support Windows x86, Linux x86/ARM, and Android armeabi-v7a/x86.

### Platform notes

**MSVC** — Debug and Release are separate archives. An OpenSSL Debug build links the `/MDd`
CRT, so linking a Release (`/MD`) library into a Debug app produces `LNK2038`. For
multi-config generators like Visual Studio, both archives are downloaded and wired up via
`IMPORTED_LOCATION_DEBUG` / `IMPORTED_LOCATION_RELEASE`, so switching configuration in the
IDE picks the right one automatically. `RelWithDebInfo` and `MinSizeRel` map to Release.

PDBs are not shipped. They are only usable with the matching OpenSSL sources, and the paths
baked into a PDB point at the CI runner's filesystem, so you could not step into OpenSSL
regardless. MSVC may emit `LNK4099` (PDB not found) when linking the Debug archive — it's a
warning, not an error. If you need to debug into OpenSSL itself, build from source
(method 2), which does produce and wire up PDBs.

**MinGW** — Prebuilts are built in the MSYS2 `MINGW64` environment, which is **msvcrt**
based. This matches the CRT of Qt's bundled MinGW (e.g. Qt 5.15.2 / MinGW 8.1), so they
link together. If you use a **UCRT-based toolchain** (MSYS2 `UCRT64`, the default in recent
MSYS2), the CRT differs and linking may break — build from source instead.

**Linux** — GCC and Clang share the same archive. It's a static C library, so the two
compilers are ABI-compatible here. Both x64 and arm64 are built inside the
`manylinux2014` container (**glibc 2.17**), so the archives link on virtually any modern
distribution, including older toolchains like `gcc-toolset-11` on RHEL8. (Building against a
newer glibc redirects `strtol`/`strtoll`/… to `__isoc23_*@GLIBC_2.38` symbols that older
systems don't provide, producing `undefined reference to __isoc23_strtol` at link time —
building against 2.17 avoids that entirely.) On musl (Alpine, etc.) use method 2.

**Android** — Built at API 21. A library built for a lower API works on higher ones, so any
app with `minSdk` 21 or above can use it. Below 21, use method 2.

---

## Android 16 KB page alignment

Supported, as required by Android 15+ devices and the Play Store.

A static library (`.a`) has no notion of ELF segment alignment — 16 KB alignment is decided
when the **final `.so` that swallows the `.a` is linked**. So instead of a build flag, the
`OpenSSL::Crypto` target propagates the link options to consumers:

```
-Wl,-z,max-page-size=16384
-Wl,-z,common-page-size=16384
```

In other words, **just linking `OpenSSL::SSL` makes your `.so` 16 KB aligned**. No extra
configuration. This applies to both prebuilt and source builds.

To verify:

```bash
llvm-readelf -l libyour_app.so | grep LOAD
# Align should read 0x4000 (16384)
```

---

## Options

| Option | Default | Description |
|---|---|---|
| `OPENSSL_CMAKE_USE_PREBUILT` | `ON` | Set to `OFF` to build from source |
| `OPENSSL_CMAKE_PREBUILT_TAG` | `v1.2.0` | Release tag to fetch prebuilts from |
| `OPENSSL_CMAKE_PREBUILT_URL` | (empty) | Override the asset base URL — for internal mirrors / air-gapped networks |

### Air-gapped networks

Copy the release assets (`*.tar.gz` and `prebuilt-manifest.cmake`) to an internal server,
then:

```bash
cmake -B build -DOPENSSL_CMAKE_PREBUILT_URL=https://internal.example.com/openssl-cmake/v1.2.0
```

`file:///` URLs work too, so you can point at a local directory.

---

## Disk usage

With prebuilts, each consuming project only creates:

```
<build-dir>/_deps/openssl-cmake-src/     ~500 KB   (CMake scripts only)
<build-dir>/prebuilt/<triple>/           ~20-60 MB (headers + static libraries)
```

A source build, by contrast, creates a full OpenSSL source tree (~250 MB), a toolchain
(hundreds of MB on Windows for Perl/MSYS2/NASM), and object files — **per project**.
Switching to prebuilts makes all of that go away.

Deleting the build directory means the prebuilt is re-downloaded (a few seconds). If you
have many projects and clean often, point `FETCHCONTENT_BASE_DIR` at a shared path to share
`_deps` across projects.

---

## Version history

### v1.2.0
**ARM64 prebuilts + older-glibc Linux archives.**

- New prebuilt platforms: **Windows arm64 (MSVC, Debug + Release)** and **Linux arm64
  (GCC / Clang)**. Linux arm64 shares one archive across gcc and clang, same as x64.
- Windows arm64 is built natively on the `windows-11-arm` GitHub-hosted runner; Linux arm64
  natively on `ubuntu-24.04-arm`.
- **Linux archives are now built inside `manylinux2014` (glibc 2.17)** instead of on the
  bare `ubuntu-latest` runner. Newer glibc (>= 2.38) redirects `strtol` & friends to
  `__isoc23_*@GLIBC_2.38`, which broke linking on older toolchains (e.g. `gcc-toolset-11`
  on RHEL8) with `undefined reference to __isoc23_strtol`. Building against glibc 2.17 fixes
  this and makes the archives link on virtually any modern Linux.
- Windows ARM64 MinGW is intentionally not shipped: there is no mainstream GCC
  `aarch64-w64-mingw32` toolchain. Use MSVC (prebuilt) or build from source.

### v1.1.0
**Prebuilt binary distribution.**

- GitHub Actions builds static libraries for 5 platforms on tag push and publishes them as
  Release assets
- New `OPENSSL_CMAKE_USE_PREBUILT` option (**default `ON`**) — detects OS / architecture /
  compiler at configure time and downloads the matching archive with SHA256 verification
- Unsupported combinations fail explicitly at configure time, printing the supported list
- Multi-config MSVC generators: both Debug and Release archives are fetched and attached via
  `IMPORTED_LOCATION_<CONFIG>`, preventing `LNK2038` CRT mismatches
- Android 16 KB page alignment link options propagated from the IMPORTED target (applies to
  source builds too)
- `OPENSSL_CMAKE_PREBUILT_URL` override for air-gapped networks
- Fixed: source builds now run in `<build-dir>/openssl-build/` instead of the build root.
  Makefile generators write their own `Makefile` there and were clobbering OpenSSL's.
- The source build path is otherwise unchanged and still available via
  `OPENSSL_CMAKE_USE_PREBUILT=OFF`

### v1.0.0
**Initial release. Source builds only.**

- Downloads OpenSSL 3.6.1 source and builds it in place as static libraries
- Supports Windows (MSVC / MinGW), Linux, and Android (NDK cross-compilation)
- Automatically acquires the build toolchain — Strawberry Perl, NASM, jom, MSYS2
- Provides `OpenSSL::SSL` / `OpenSSL::Crypto` IMPORTED targets
- CMake 3.15 or newer

---

## Roadmap

- **v1.3.0** — macOS support (Apple Silicon / Intel). There is currently no Darwin build
  path, so source-build support has to come first.
- Under consideration — a shared cross-project cache directory

---

## Requirements

- CMake 3.15 or newer
- Prebuilt: network access at configure time
- Source build: a C/C++ compiler (Perl, NASM, make, etc. are acquired automatically)
