#!/usr/bin/env bash
# Build the static Clang C++ libraries for one platform and pack them.
# Usage: ./build.sh <linux-x86_64|macos-arm64|macos-x86_64>
# Env:   JOBS=<n>               parallel jobs (default: number of cores)
#        STOP_AFTER=configure   stop after the CMake configure step
set -euo pipefail

platform="${1:-}"
case "$platform" in
  linux-x86_64 | macos-arm64 | macos-x86_64) ;;
  *)
    echo "usage: $0 <linux-x86_64|macos-arm64|macos-x86_64>" >&2
    exit 2
    ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root"

# shellcheck source=llvm.version
. ./llvm.version
: "${LLVM_VERSION:?missing in llvm.version}"
: "${LLVM_SRC_SHA256:?missing in llvm.version}"

if [ -n "${JOBS:-}" ]; then
  jobs="$JOBS"
elif command -v nproc > /dev/null 2>&1; then
  jobs="$(nproc)"
else
  jobs="$(sysctl -n hw.ncpu)"
fi

name="clang-static-${LLVM_VERSION}-${platform}"
cache="$root/.cache"
tarball="$cache/llvm-project-${LLVM_VERSION}.src.tar.xz"
srcdir="$cache/llvm-project-${LLVM_VERSION}.src"
builddir="$root/build/$platform"
pkg="$root/out/$name"
archive="$root/out/$name.tar.xz"

sha256_of() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

mkdir -p "$cache" "$root/out"

# 1. Fetch the source tarball unless it is in the cache.
if [ ! -f "$tarball" ]; then
  url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz"
  echo "fetching $url"
  curl -fL --retry 3 -o "$tarball.part" "$url"
  mv "$tarball.part" "$tarball"
fi

# 2. Check the hash before unpacking.
actual="$(sha256_of "$tarball")"
if [ "$actual" != "$LLVM_SRC_SHA256" ]; then
  echo "sha256 mismatch for $tarball" >&2
  echo "  expected $LLVM_SRC_SHA256" >&2
  echo "  actual   $actual" >&2
  exit 1
fi

if [ ! -f "$srcdir/llvm/CMakeLists.txt" ]; then
  rm -rf "$srcdir"
  tar -xJf "$tarball" -C "$cache"
fi

# 3. Configure.
# Rule: LLVM_TARGETS_TO_BUILD is empty. Clang's libraries need no code
# generation back end. Use the host target only if configure fails without it.
cmake_args=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  "-DCMAKE_INSTALL_PREFIX=$pkg"
  -DLLVM_ENABLE_PROJECTS=clang
  -DLLVM_TARGETS_TO_BUILD=
  -DBUILD_SHARED_LIBS=OFF
  -DLLVM_BUILD_LLVM_DYLIB=OFF
  -DLLVM_LINK_LLVM_DYLIB=OFF
  -DCLANG_LINK_CLANG_DYLIB=OFF
  -DLLVM_BUILD_TOOLS=OFF
  -DLLVM_BUILD_UTILS=OFF
  -DCLANG_BUILD_TOOLS=OFF
  -DLLVM_INCLUDE_TESTS=OFF
  -DLLVM_INCLUDE_BENCHMARKS=OFF
  -DLLVM_INCLUDE_EXAMPLES=OFF
  -DLLVM_INCLUDE_DOCS=OFF
  -DCLANG_INCLUDE_TESTS=OFF
  -DCLANG_INCLUDE_DOCS=OFF
  -DCLANG_BUILD_EXAMPLES=OFF
  -DCLANG_ENABLE_STATIC_ANALYZER=OFF
  -DLLVM_ENABLE_ZLIB=OFF
  -DLLVM_ENABLE_ZSTD=OFF
  -DLLVM_ENABLE_LIBXML2=OFF
  -DLLVM_ENABLE_LIBEDIT=OFF
  -DLLVM_ENABLE_LIBPFM=OFF
  -DLLVM_ENABLE_BINDINGS=OFF
  -DLLVM_ENABLE_ASSERTIONS=OFF
)
case "$platform" in
  macos-arm64)
    cmake_args+=(-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0)
    ;;
  macos-x86_64)
    cmake_args+=(-DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0)
    ;;
esac

start="$(date +%s)"
cmake -S "$srcdir/llvm" -B "$builddir" "${cmake_args[@]}"

if [ "${STOP_AFTER:-}" = "configure" ]; then
  echo "stopped after configure (STOP_AFTER=configure)"
  exit 0
fi

# 4. Build and install (libraries, headers, CMake files, resource headers).
rm -rf "$pkg"
cmake --build "$builddir" --parallel "$jobs"
cmake --install "$builddir"

# 5. Licences and version.
cp "$srcdir/llvm/LICENSE.TXT" "$pkg/LICENSE-LLVM.TXT"
cp "$srcdir/clang/LICENSE.TXT" "$pkg/LICENSE-Clang.TXT"
printf 'LLVM_VERSION=%s\nPLATFORM=%s\n' "$LLVM_VERSION" "$platform" > "$pkg/VERSION"

# 6. Pack deterministically: sorted names, fixed mtime, owner 0.
# We set every mtime first, then sort the name list ourselves. That works the
# same with GNU tar (Linux) and bsdtar (macOS), which has no --sort or --mtime.
# xz runs on one thread so the bytes do not depend on the core count.
find "$pkg" -exec touch -h -t 202001010000 {} +
(
  cd "$root/out"
  find "$name" -print | LC_ALL=C sort > "$name.list"
  if tar --version 2> /dev/null | grep -q 'GNU tar'; then
    tar --no-recursion --owner=0 --group=0 --numeric-owner --format=gnu \
      -T "$name.list" -cf - | xz -T1 -9 > "$archive"
  else
    tar -n --uid 0 --gid 0 --numeric-owner --format gnutar \
      -T "$name.list" -cf - | xz -T1 -9 > "$archive"
  fi
  rm -f "$name.list"
)

# 7. Hash.
(cd "$root/out" && printf '%s  %s\n' "$(sha256_of "$archive")" "$name.tar.xz" > "$name.tar.xz.sha256")

end="$(date +%s)"
echo "built $archive in $((end - start)) s"
