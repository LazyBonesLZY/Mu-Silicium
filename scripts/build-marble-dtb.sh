#!/usr/bin/env bash
#
# Compile the Xiaomi marble (POCO F5 / Redmi Note 12 Turbo) device tree
# for embedding in the UEFI firmware, without modifying the kernel tree.
#
# The preprocessor and dtc only read from the kernel tree; all intermediate
# files live in a temporary directory.
#
# SPDX-License-Identifier: BSD-2-Clause-Patent
#
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-marble-dtb.sh [OUTPUT_DTB]

Compile the marble device tree to a flattened device tree blob (DTB) and
write a FdtBlob/Source.txt file next to it.

Arguments:
  OUTPUT_DTB    Output DTB path. Default:
                <Mu-Silicium>/Platforms/Xiaomi/marblePkg/FdtBlob/sm8475-xiaomi-marble.dtb

Environment:
  KERNEL_DIR    Mainline kernel source tree.
                Default: /workspace/marble/src/linux-marble
  DTS           Device tree source file.
                Default: $KERNEL_DIR/arch/arm64/boot/dts/qcom/sm8475-xiaomi-marble.dts
  REPO_ROOT     Mu-Silicium repository root (autodetected by default).
  SOURCE_TXT    Source.txt path. Default: directory of OUTPUT_DTB/Source.txt

Examples:
  scripts/build-marble-dtb.sh
  KERNEL_DIR=/path/to/linux scripts/build-marble-dtb.sh /tmp/marble.dtb
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Autodetect the Mu-Silicium root so this script works both from
# Mu-Silicium/scripts and from a sibling uefi/scripts directory.
repo_root="${REPO_ROOT:-}"
if [ -z "$repo_root" ]; then
  for candidate in "$script_dir/.." "$script_dir/../Mu-Silicium"; do
    if [ -d "$candidate/Platforms/Xiaomi/marblePkg" ]; then
      repo_root="$(cd -- "$candidate" && pwd)"
      break
    fi
  done
fi

if [ -z "$repo_root" ] || [ ! -d "$repo_root/Platforms/Xiaomi/marblePkg" ]; then
  echo "error: cannot find Platforms/Xiaomi/marblePkg; set REPO_ROOT" >&2
  exit 1
fi

kernel_dir="${KERNEL_DIR:-}"
if [ -z "$kernel_dir" ]; then
  if [ -d "$repo_root/../../src/linux-marble" ]; then
    kernel_dir="$(cd -- "$repo_root/../../src/linux-marble" && pwd)"
  else
    kernel_dir="/workspace/marble/src/linux-marble"
  fi
fi

dts="${DTS:-$kernel_dir/arch/arm64/boot/dts/qcom/sm8475-xiaomi-marble.dts}"
output="${1:-$repo_root/Platforms/Xiaomi/marblePkg/FdtBlob/sm8475-xiaomi-marble.dtb}"

for tool in cpp dtc git; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: required tool '$tool' not found in PATH" >&2
    exit 1
  fi
done

if [ ! -f "$dts" ]; then
  echo "error: DTS not found: $dts" >&2
  exit 1
fi

for include_dir in \
  "$kernel_dir/include" \
  "$kernel_dir/arch/arm64/boot/dts" \
  "$kernel_dir/arch/arm64/boot/dts/qcom" \
  "$kernel_dir/scripts/dtc/include-prefixes"
do
  if [ ! -d "$include_dir" ]; then
    echo "error: kernel include directory not found: $include_dir" >&2
    exit 1
  fi
done

if ! git -C "$kernel_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not a git work tree: $kernel_dir" >&2
  exit 1
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/marble-dtb.XXXXXX")"
cleanup() {
  rm -rf -- "$tmpdir"
}
trap cleanup EXIT INT TERM

echo "Preprocessing: $dts"
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I "$kernel_dir/include" \
  -I "$kernel_dir/arch/arm64/boot/dts" \
  -I "$kernel_dir/arch/arm64/boot/dts/qcom" \
  -I "$kernel_dir/scripts/dtc/include-prefixes" \
  "$dts" -o "$tmpdir/dts.preprocessed"

mkdir -p -- "$(dirname -- "$output")"

echo "Compiling:     $output"
dtc -@ -I dts -O dtb "$tmpdir/dts.preprocessed" -o "$output"

# Make sure the result is a valid DTB that dtc can read back.
if ! dtc -I dtb -O dts "$output" -o "$tmpdir/verify.dts" >/dev/null 2>&1; then
  echo "error: produced DTB could not be decompiled: $output" >&2
  exit 1
fi

commit="$(git -C "$kernel_dir" rev-parse HEAD)"
repo_url="$(git -C "$kernel_dir" remote get-url origin 2>/dev/null || true)"
if [ -z "$repo_url" ]; then
  repo_url="$(git -C "$kernel_dir" config --get remote.origin.url 2>/dev/null || true)"
fi
if [ -z "$repo_url" ]; then
  echo "warning: kernel has no origin remote; Source.txt REPO will be 'unknown'" >&2
  repo_url="unknown"
else
  # Match the Source.txt style used by the other device packages.
  repo_url="${repo_url%.git}"
fi

source_txt="${SOURCE_TXT:-$(dirname -- "$output")/Source.txt}"
mkdir -p -- "$(dirname -- "$source_txt")"
printf 'REPO: %s\nCOMMIT: %s\n' "$repo_url" "$commit" > "$source_txt"

echo "Wrote:         $output ($(wc -c < "$output") bytes)"
echo "Wrote:         $source_txt"
