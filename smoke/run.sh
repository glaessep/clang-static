#!/usr/bin/env bash
# Build a small program against a package and check its output.
# Usage: ./smoke/run.sh <package-dir>
set -euo pipefail

if [ $# -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: $0 <package-dir>" >&2
  exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg="$(cd "$1" && pwd)"
build="$here/build"

rm -rf "$build"
cmake -S "$here" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  "-DCMAKE_PREFIX_PATH=$pkg"
cmake --build "$build"

actual="$("$build/smoke" "$here/sample.cpp")"
expected="$(cat "$here/expected.txt")"
if [ "$actual" != "$expected" ]; then
  echo "smoke test failed: output differs" >&2
  diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") >&2 || true
  exit 1
fi
echo "smoke test passed"
