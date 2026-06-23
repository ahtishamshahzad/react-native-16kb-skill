#!/usr/bin/env bash
# check_elf_alignment.sh — verify native (.so) libraries in an APK/AAB are 16KB ELF-aligned.
#
# 16KB compliance requires every LOAD segment of every bundled .so to be aligned
# to 2**14 (16384). This script unpacks the archive, inspects each .so with
# objdump/readelf, and reports PASS/FAIL per library.
#
# Usage:
#   ./check_elf_alignment.sh path/to/app-release.apk
#   ./check_elf_alignment.sh path/to/app-release.aab
#   ./check_elf_alignment.sh path/to/dir-of-so-files/
#
# Requires: unzip, and one of: llvm-objdump | objdump | readelf
#   (NDK ships llvm-objdump at $ANDROID_NDK/toolchains/llvm/prebuilt/*/bin/)
#
# Exit codes: 0 = all aligned, 1 = misaligned lib found, 2 = usage/tooling error.

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; NC=$'\033[0m'

usage() { echo "Usage: $0 <app.apk|app.aab|dir-of-.so>"; exit 2; }
[ $# -eq 1 ] || usage
INPUT="$1"
[ -e "$INPUT" ] || { echo "${RED}Not found:${NC} $INPUT"; exit 2; }

# --- pick an ELF inspector -------------------------------------------------
OBJDUMP=""
for cand in "${ANDROID_NDK:-}"/toolchains/llvm/prebuilt/*/bin/llvm-objdump \
            llvm-objdump objdump; do
  if command -v "$cand" >/dev/null 2>&1 || ls $cand >/dev/null 2>&1; then
    OBJDUMP=$(command -v "$cand" 2>/dev/null || ls $cand 2>/dev/null | head -1)
    [ -n "$OBJDUMP" ] && break
  fi
done
USE_READELF=""
if [ -z "$OBJDUMP" ]; then
  if command -v readelf >/dev/null 2>&1; then USE_READELF="readelf"
  else echo "${RED}Need llvm-objdump, objdump, or readelf on PATH.${NC}"; exit 2; fi
fi

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# --- collect .so files -----------------------------------------------------
collect_dir=""
case "$INPUT" in
  *.apk|*.aab|*.zip)
    unzip -q -o "$INPUT" -d "$WORK" '*.so' 2>/dev/null || true
    collect_dir="$WORK" ;;
  *)
    [ -d "$INPUT" ] || { echo "${RED}Expected .apk/.aab or a directory.${NC}"; exit 2; }
    collect_dir="$INPUT" ;;
esac

mapfile -t SO_FILES < <(find "$collect_dir" -type f -name '*.so' | sort)
if [ "${#SO_FILES[@]}" -eq 0 ]; then
  echo "${YELLOW}No .so files found.${NC} If this is an RN app, it normally ships native libs — check the build."
  exit 0
fi

# --- check each lib --------------------------------------------------------
fail=0
echo "Checking ${#SO_FILES[@]} native librar$([ ${#SO_FILES[@]} -eq 1 ] && echo y || echo ies) for 16KB alignment..."
echo
for so in "${SO_FILES[@]}"; do
  name="${so#$collect_dir/}"
  if [ -n "$USE_READELF" ]; then
    # readelf: ALIGN column of LOAD program headers (hex). 16KB = 0x4000.
    aligns=$(readelf -lW "$so" 2>/dev/null | awk '/LOAD/{print $NF}')
  else
    # objdump: "align 2**N" on LOAD segments. 16KB = 2**14.
    aligns=$("$OBJDUMP" -p "$so" 2>/dev/null | awk '/LOAD/{for(i=1;i<=NF;i++) if($i ~ /2\*\*/) print $i}')
  fi

  ok=1
  for a in $aligns; do
    case "$a" in
      2\*\*14|2\*\*15|2\*\*16|0x4000|0x8000|0x10000) : ;;          # 16KB or larger → ok
      "") : ;;
      *) ok=0 ;;
    esac
  done

  if [ "$ok" -eq 1 ]; then
    echo "  ${GREEN}PASS${NC}  $name"
  else
    echo "  ${RED}FAIL${NC}  $name   (align: ${aligns:-unknown} — needs 2**14 / 0x4000)"
    fail=1
  fi
done

echo
if [ "$fail" -eq 0 ]; then
  echo "${GREEN}All native libraries are 16KB-aligned.${NC}"
  exit 0
else
  echo "${RED}One or more libraries are NOT 16KB-aligned.${NC} Upgrade the responsible dependency or toolchain (AGP 8.5.1+, NDK r28+, useLegacyPackaging=false)."
  exit 1
fi
