#!/usr/bin/env bash
# try-bambo.sh: boot BamboOS in a full-screen QEMU window.
#
#   scripts/try-bambo.sh [path/to.iso | path/to-aarch64.qcow2]
#
# With no argument, an Apple Silicon Mac boots the newest arm64 image in out/
# (scripts/build-arm64.sh) at native CPU speed through the Hypervisor
# framework. Everything else boots the newest x86 ISO. On Apple Silicon the
# x86 ISO runs under emulation and is very slow.
#
# The arm64 VM keeps its changes in out/try-arm64.qcow2, an overlay on the
# built image. Delete that file to start from a clean image.
#
# The guest gets one mode with the aspect ratio of the main display and QEMU
# stretches it over the whole screen.
#
# Settings (environment):
#   BAMBO_RES=1512x982    guest resolution. Default on a Mac: the main display in
#                         pixels for the arm64 image (sharp on Retina, BamboOS
#                         scales 2x), in points for the emulated x86 ISO (4x fewer
#                         pixels to draw). Set it to the point size if arm64 lags.
#   BAMBO_WINDOWED=1      start in a window instead of full screen
#   BAMBO_MEM=4096        RAM in MiB
#   BAMBO_CPUS=4
#   BAMBO_DISK=out/test-disk.qcow2   x86 only: blank disk for bambo-install (created if missing)
#   BAMBO_QEMU_EXTRA="..."           extra QEMU arguments
#
# Leave: Ctrl+Option+G releases the keyboard, then Cmd+Q quits (Cmd+F leaves full screen).
set -euo pipefail

cd "$(dirname "$0")/.."

newest() { find out -maxdepth 1 -name "$1" -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n1 || true; }

os="$(uname -s)"
media="${1:-}"
if [[ -z $media && $os == Darwin && $(uname -m) == arm64 ]]; then
  media="$(newest 'bambo-os-*-aarch64.qcow2')"
fi
[[ -n $media ]] || media="$(newest 'bambo-os-*.iso')"
[[ -n $media && -r $media ]] || { echo "try-bambo: nothing to boot in out/. Run 'make arm64' (Apple Silicon) or 'make iso', or pass a path." >&2; exit 1; }
if [[ $media == *.qcow2 ]]; then arch=aarch64; else arch=x86_64; fi
qemu="qemu-system-$arch"
command -v "$qemu" >/dev/null 2>&1 || { echo "try-bambo: $qemu not found (macOS: brew install qemu)." >&2; exit 1; }

# Main display size: "3024 x 1964 Retina" -> 1512x982 in points, or with
# "pixels" as the argument the full 3024x1964.
host_res() {
  local line w h
  line="$(system_profiler SPDisplaysDataType 2>/dev/null | grep -m1 'Resolution:' || true)"
  if [[ $line =~ ([0-9]+)\ x\ ([0-9]+) ]]; then
    w="${BASH_REMATCH[1]}" h="${BASH_REMATCH[2]}"
    if [[ $line == *Retina* && ${1:-points} != pixels ]]; then w=$((w / 2)) h=$((h / 2)); fi
    echo "$((w / 8 * 8))x$((h / 2 * 2))"
  else
    echo 1280x800
  fi
}

res="${BAMBO_RES:-}"
if [[ -z $res ]]; then
  if [[ $os == Darwin && $arch == aarch64 ]]; then res="$(host_res pixels)"
  elif [[ $os == Darwin ]]; then res="$(host_res)"
  else res=1920x1080; fi
fi
[[ $res =~ ^([0-9]+)x([0-9]+)$ ]] || { echo "try-bambo: BAMBO_RES must look like 1512x982." >&2; exit 1; }
xres="${BASH_REMATCH[1]}" yres="${BASH_REMATCH[2]}"

if [[ ${BAMBO_WINDOWED:-0} == 1 ]]; then full=off; else full=on; fi

args=(-name BamboOS -m "${BAMBO_MEM:-4096}" -smp "${BAMBO_CPUS:-4}"
  -device qemu-xhci -device usb-tablet)

if [[ $arch == aarch64 ]]; then
  [[ $os == Darwin && $(uname -m) == arm64 ]] || { echo "try-bambo: the arm64 image needs an Apple Silicon Mac." >&2; exit 1; }
  share="$(dirname "$(realpath "$(command -v "$qemu")")")/../share/qemu"
  code="$share/edk2-aarch64-code.fd"
  [[ -r $code && -r $share/edk2-arm-vars.fd ]] || { echo "try-bambo: UEFI firmware not found in $share." >&2; exit 1; }
  overlay=out/try-arm64.qcow2 vars=out/try-arm64-vars.fd
  # The VM disk is an overlay on one image. Compare the image it was made from,
  # not file times: a running VM keeps the overlay newer than any new image.
  backing="$(qemu-img info -U "$overlay" 2>/dev/null | sed -n 's/^backing file: //p')"
  if [[ ! -e $overlay || $backing != "$(realpath "$media")" ]]; then
    echo "try-bambo: new VM disk $overlay on top of $media"
    rm -f "$overlay" "$vars"
    qemu-img create -q -f qcow2 -F qcow2 -b "$(realpath "$media")" "$overlay"
  fi
  [[ -e $vars ]] || cp "$share/edk2-arm-vars.fd" "$vars"
  # The firmware has no virtio keyboard driver, so the keyboard is USB.
  args+=(-machine "virt,gic-version=3" -accel hvf -cpu host
    -drive "if=pflash,format=raw,readonly=on,file=$code"
    -drive "if=pflash,format=raw,file=$vars"
    -drive "file=$overlay,if=virtio,format=qcow2"
    -device usb-kbd -nic "user,model=virtio-net-pci"
    -device "virtio-gpu-pci,xres=$xres,yres=$yres"
    -display "cocoa,full-screen=$full,zoom-to-fit=on,full-grab=on")
else
  disk="${BAMBO_DISK:-out/test-disk.qcow2}"
  if [[ ! -e $disk ]]; then
    mkdir -p "$(dirname "$disk")"
    qemu-img create -q -f qcow2 "$disk" 32G
  fi
  args+=(-drive "file=$disk,if=virtio,format=qcow2" -cdrom "$media" -boot d)
  if [[ $os == Darwin ]]; then
    if [[ $(uname -m) == x86_64 ]]; then
      args+=(-accel hvf -cpu host)
    else
      echo "try-bambo: Apple Silicon runs this x86 ISO under emulation. Expect about 9 minutes to the desktop."
      args+=(-accel "tcg,thread=multi" -cpu max)
    fi
    # A plain VGA adapter ignores window-size hints. With virtio-vga, QEMU's
    # Cocoa display tells the guest to use the size of the boot window (720x400).
    args+=(-vga none -device "VGA,xres=$xres,yres=$yres"
      -display "cocoa,full-screen=$full,zoom-to-fit=on,full-grab=on")
  else
    args+=(-enable-kvm -cpu host -vga none -device "virtio-vga-gl,xres=$xres,yres=$yres"
      -display "gtk,gl=on,full-screen=$full")
  fi
fi

# full-grab sends Cmd+Space, Cmd+Tab and friends to the guest. It needs the
# Accessibility permission for the app that starts QEMU and is skipped without it.
echo "try-bambo: $media ($arch) at ${xres}x${yres}, full screen $full"
# shellcheck disable=SC2086
exec "$qemu" "${args[@]}" ${BAMBO_QEMU_EXTRA:-}
