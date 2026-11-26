#!/usr/bin/env bash
# try-bambo.sh: boot the BamboOS ISO in a full-screen QEMU window.
#
#   scripts/try-bambo.sh [path/to.iso]
#
# The guest gets one fixed mode with the aspect ratio of the main display, and
# QEMU stretches it over the whole screen. A plain VGA adapter is used on macOS
# because it ignores window-size hints: with virtio-vga, QEMU's Cocoa display
# tells the guest to use the size of the boot window (720x400).
#
# Settings (environment):
#   BAMBO_RES=1512x982    guest resolution (default: main display in points)
#   BAMBO_WINDOWED=1      start in a window instead of full screen
#   BAMBO_MEM=4096        RAM in MiB
#   BAMBO_CPUS=4
#   BAMBO_DISK=out/test-disk.qcow2   blank disk for bambo-install (created if missing)
#   BAMBO_QEMU_EXTRA="..."           extra QEMU arguments
#
# Leave: Ctrl+Option+G releases the keyboard, then Cmd+Q quits (Cmd+F leaves full screen).
set -euo pipefail

cd "$(dirname "$0")/.."

iso="${1:-}"
if [[ -z $iso ]]; then
  iso="$(find out -maxdepth 1 -name 'bambo-os-*.iso' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n1 || true)"
fi
[[ -n $iso && -r $iso ]] || { echo "try-bambo: no ISO found. Run 'make iso' or pass a path." >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "try-bambo: qemu-system-x86_64 not found (macOS: brew install qemu)." >&2; exit 1; }

disk="${BAMBO_DISK:-out/test-disk.qcow2}"
if [[ ! -e $disk ]]; then
  mkdir -p "$(dirname "$disk")"
  qemu-img create -f qcow2 "$disk" 32G >/dev/null
fi

# Main display size in points: "3024 x 1964 Retina" -> 1512x982.
host_res() {
  local line w h
  line="$(system_profiler SPDisplaysDataType 2>/dev/null | grep -m1 'Resolution:' || true)"
  if [[ $line =~ ([0-9]+)\ x\ ([0-9]+) ]]; then
    w="${BASH_REMATCH[1]}" h="${BASH_REMATCH[2]}"
    if [[ $line == *Retina* ]]; then w=$((w / 2)) h=$((h / 2)); fi
    echo "$((w / 8 * 8))x$((h / 2 * 2))"
  else
    echo 1280x800
  fi
}

os="$(uname -s)"
res="${BAMBO_RES:-}"
if [[ -z $res ]]; then
  if [[ $os == Darwin ]]; then res="$(host_res)"; else res=1920x1080; fi
fi
[[ $res =~ ^([0-9]+)x([0-9]+)$ ]] || { echo "try-bambo: BAMBO_RES must look like 1512x982." >&2; exit 1; }
xres="${BASH_REMATCH[1]}" yres="${BASH_REMATCH[2]}"

if [[ ${BAMBO_WINDOWED:-0} == 1 ]]; then full=off; else full=on; fi

args=(-name BamboOS -m "${BAMBO_MEM:-4096}" -smp "${BAMBO_CPUS:-4}"
  -device qemu-xhci -device usb-tablet
  -drive "file=$disk,if=virtio,format=qcow2"
  -cdrom "$iso" -boot d)

if [[ $os == Darwin ]]; then
  if [[ $(uname -m) == x86_64 ]]; then
    args+=(-accel hvf -cpu host)
  else
    echo "try-bambo: Apple Silicon runs this x86 ISO under emulation. Expect about 9 minutes to the desktop."
    args+=(-accel tcg,thread=multi -cpu max)
  fi
  # full-grab sends Cmd+Space, Cmd+Tab and friends to the guest. It needs the
  # Accessibility permission for the app that starts QEMU and is skipped without it.
  args+=(-vga none -device "VGA,xres=$xres,yres=$yres"
    -display "cocoa,full-screen=$full,zoom-to-fit=on,full-grab=on")
else
  args+=(-enable-kvm -cpu host -vga none -device "virtio-vga-gl,xres=$xres,yres=$yres"
    -display "gtk,gl=on,full-screen=$full")
fi

echo "try-bambo: $iso at ${xres}x${yres}, full screen $full"
# shellcheck disable=SC2086
exec qemu-system-x86_64 "${args[@]}" ${BAMBO_QEMU_EXTRA:-}
