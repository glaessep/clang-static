# clang-static

A build recipe for the static libraries of Clang's C++ API.

It builds `libclang*.a` and the `libLLVM*.a` files they need from an upstream LLVM
release. The package also holds the headers, the CMake package files and Clang's own
resource headers. This repository holds no LLVM source and no fork. The version and the
source hash are in `llvm.version`.

Each release has one package per platform, with a `.sha256` file for each and one
`SHA256SUMS` file:

| Platform | Package |
| -------- | ------- |
| `linux-x86_64` | `clang-static-<version>-linux-x86_64.tar.xz` |
| `macos-arm64` | `clang-static-<version>-macos-arm64.tar.xz` (macOS 13 or newer) |
| `macos-x86_64` | `clang-static-<version>-macos-x86_64.tar.xz` (macOS 13 or newer) |

## Use a package

Unpack it, then in your `CMakeLists.txt`:

```cmake
list(APPEND CMAKE_PREFIX_PATH /path/to/clang-static-<version>-<platform>)
find_package(Clang REQUIRED CONFIG)
target_include_directories(app PRIVATE ${CLANG_INCLUDE_DIRS} ${LLVM_INCLUDE_DIRS})
target_link_libraries(app PRIVATE clangTooling clangIndex)
```

Build your code without RTTI, as LLVM does (`-fno-rtti`).

## Build by hand

You need CMake, Ninja, a C++17 compiler, `curl`, `tar` and `xz`.

```sh
./build.sh linux-x86_64        # or macos-arm64, macos-x86_64
./smoke/run.sh out/clang-static-<version>-linux-x86_64
```

- `build.sh` fetches the source into `.cache/` and checks its sha256. It builds in
  `build/<platform>/` and writes the package, the archive and its `.sha256` to `out/`.
- `JOBS=<n>` sets the parallel jobs. The default is the number of cores.
- `STOP_AFTER=configure` stops after the CMake configure step.
- `smoke/run.sh` builds a small program with `clang::index` against the package. It fails
  unless the output matches `smoke/expected.txt`.

A full build takes over an hour.

## Cut a release

Push a tag `v<llvm-version>-<n>`, for example `v23.1.6-1`. The workflow builds the three
platforms, runs the smoke test on each, and creates the release with all archives and
`SHA256SUMS`. To check a build without a release, run the workflow by hand
(`workflow_dispatch`). It keeps the archives as artifacts.

To move to a new LLVM version, change both lines of `llvm.version`.

## What is left out on purpose

- Tools and utilities (`clang`, `clangd`, `llvm-*`).
- Tests, benchmarks, examples and docs.
- The Clang static analyzer.
- Code generation back ends: `LLVM_TARGETS_TO_BUILD` is empty.
- Shared libraries and the LLVM and Clang dylibs.
- zlib, zstd, libxml2, libedit, libpfm and language bindings.
- Assertions.

## Licence

The recipe (this repository) is under Apache-2.0, see `LICENSE`. Each package carries
LLVM's and Clang's own licence files, `LICENSE-LLVM.TXT` and `LICENSE-Clang.TXT`.
