#!/usr/bin/env bash
# judge.sh — compile-judge a single BiSheng C file.
#
# Usage:   judge.sh <file.cbs>
# Exit:    0 = the BSC compiler accepted the file (PASS), non-zero = FAIL.
#
# Environment:
#   BSC_CLANG        (required) path to a built BiSheng C clang binary
#   BSC_JUDGE_MODE   syntax (default) | binary
#                    syntax: -fsyntax-only — all BSC semantic checks (ownership,
#                            borrow, safe-zone, nullability) run in Sema, so this
#                            is a full language-level judgement without needing a
#                            host sysroot or linker.
#                    binary: additionally code-gens and links an executable.
#   BSC_JUDGE_FLAGS  extra flags appended to the compile line (e.g. -I dirs)
#   BSC_SYSROOT      sysroot passed as -isysroot. On macOS this defaults to
#                    `xcrun --show-sdk-path` (a BSC clang built from the LLVM
#                    fork does not know the SDK location by itself, so system
#                    headers like <stdlib.h> are not found without it).
set -u

if [ $# -ne 1 ]; then
  echo "usage: judge.sh <file.cbs>" >&2
  exit 64
fi
file=$1

if [ ! -f "$file" ]; then
  echo "judge.sh: no such file: $file" >&2
  exit 66
fi

if [ -z "${BSC_CLANG:-}" ] || [ ! -x "$BSC_CLANG" ]; then
  echo "judge.sh: BSC_CLANG must point to an executable BiSheng C clang (got: '${BSC_CLANG:-}')" >&2
  exit 78
fi

mode=${BSC_JUDGE_MODE:-syntax}
extra=${BSC_JUDGE_FLAGS:-}

sysroot=${BSC_SYSROOT:-}
if [ -z "$sysroot" ] && [ "$(uname)" = "Darwin" ] && command -v xcrun >/dev/null 2>&1; then
  sysroot=$(xcrun --show-sdk-path 2>/dev/null || true)
fi
if [ -n "$sysroot" ]; then
  extra="-isysroot $sysroot $extra"
fi

case "$mode" in
  syntax)
    # shellcheck disable=SC2086
    "$BSC_CLANG" -fsyntax-only $extra "$file"
    ;;
  binary)
    out=$(mktemp -t bsc_judge)
    # shellcheck disable=SC2086
    "$BSC_CLANG" $extra "$file" -o "$out"
    rc=$?
    rm -f "$out"
    exit $rc
    ;;
  *)
    echo "judge.sh: unknown BSC_JUDGE_MODE '$mode' (want syntax|binary)" >&2
    exit 78
    ;;
esac
