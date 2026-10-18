#!/usr/bin/env bash
#
# Compile the Xiaomi marble (POCO F5 / Redmi Note 12 Turbo) device tree
# for embedding in the UEFI firmware, without modifying the kernel tree.
#
# The DTS is read from the commit pinned in FdtBlob/Source.txt using
#   git -C "$KERNEL_DIR" show "$COMMIT:<path>"
# so a dirty kernel working tree (for example local HAL/NFC/IR edits)
# cannot change the firmware blob.  The kernel tree's include paths are
# still used by cpp; the kernel tree is only ever read from.
#
# SPDX-License-Identifier: BSD-2-Clause-Patent
#
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-marble-dtb.sh [OUTPUT_DTB]

Compile the marble device tree to a flattened device tree blob (DTB) and
write a FdtBlob/Source.txt file next to it.

The DTS text is taken from the commit pinned in Source.txt (git show), so
the kernel working tree may be dirty.  If Source.txt is missing, kernel
HEAD is used and a warning is printed.  Source.txt is (re)written with the
commit that was actually used.

Arguments:
  OUTPUT_DTB    Output DTB path. Default:
                <Mu-Silicium>/Platforms/Xiaomi/marblePkg/FdtBlob/sm8475-xiaomi-marble.dtb

Environment:
  KERNEL_DIR    Mainline kernel source tree.
                Default: /workspace/marble/src/linux-marble
  DTS           Device tree source path: absolute inside KERNEL_DIR, or
                relative to KERNEL_DIR.
                Default: arch/arm64/boot/dts/qcom/sm8475-xiaomi-marble.dts
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

output="${1:-$repo_root/Platforms/Xiaomi/marblePkg/FdtBlob/sm8475-xiaomi-marble.dtb}"
source_txt="${SOURCE_TXT:-$(dirname -- "$output")/Source.txt}"

# The DTS must be addressable relative to the kernel tree so it can be
# fetched with "git show <commit>:<path>".
default_dts_rel="arch/arm64/boot/dts/qcom/sm8475-xiaomi-marble.dts"
if [ -n "${DTS:-}" ]; then
  case "$DTS" in
    /*)
      dts_rel="${DTS#"$kernel_dir"/}"
      if [ "$dts_rel" = "$DTS" ]; then
        echo "error: DTS must live inside KERNEL_DIR ($kernel_dir): $DTS" >&2
        exit 1
      fi
      ;;
    *)
      dts_rel="$DTS"
      ;;
  esac
else
  dts_rel="$default_dts_rel"
fi

for tool in cpp dtc git; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: required tool '$tool' not found in PATH" >&2
    exit 1
  fi
done

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

# Pin the build to the commit recorded in Source.txt.  Bootstrap from HEAD
# only when Source.txt does not exist yet (first run).
commit=""
if [ -f "$source_txt" ]; then
  commit="$(awk -F':[[:space:]]*' '/^COMMIT:/{print $2; exit}' "$source_txt" | tr -d '[:space:]')"
fi
if [ -z "$commit" ]; then
  commit="$(git -C "$kernel_dir" rev-parse HEAD)"
  echo "warning: no COMMIT in $source_txt; pinning to kernel HEAD $commit" >&2
else
  echo "Pinned commit: $commit (from $source_txt)"
fi

if ! git -C "$kernel_dir" cat-file -e "${commit}:${dts_rel}" 2>/dev/null; then
  echo "error: '$dts_rel' not found at commit $commit in $kernel_dir" >&2
  exit 1
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/marble-dtb.XXXXXX")"
cleanup() {
  rm -rf -- "$tmpdir"
}
trap cleanup EXIT INT TERM

# Extract the DTS from the pinned commit; quoted #includes that are not
# found next to the extracted file fall back to the kernel include paths.
dts="$tmpdir/$(basename -- "$dts_rel")"
git -C "$kernel_dir" show "${commit}:${dts_rel}" > "$dts"
echo "Extracted:     $dts_rel @ $commit"

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

# marble is a simple-framebuffer device; sanity-check the node and mode the
# UEFI display path and the kernel both rely on.
if ! grep -q 'framebuffer@b8000000' "$tmpdir/verify.dts"; then
  echo "error: DTB is missing framebuffer@b8000000" >&2
  exit 1
fi
if ! grep -Eq 'width = <(0x438|1080)>' "$tmpdir/verify.dts" || \
   ! grep -Eq 'height = <(0x960|2400)>' "$tmpdir/verify.dts"; then
  echo "error: DTB framebuffer is not 1080x2400" >&2
  exit 1
fi

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

# Keep Source.txt pinned to the commit that was actually used.
mkdir -p -- "$(dirname -- "$source_txt")"
printf 'REPO: %s\nCOMMIT: %s\n' "$repo_url" "$commit" > "$source_txt"

echo "Wrote:         $output ($(wc -c < "$output") bytes)"
echo "Wrote:         $source_txt"
