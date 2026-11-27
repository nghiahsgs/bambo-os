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
#   BAMBO_CLIPBOARD=0     macOS: do not share the clipboard with the VM
#   BAMBO_SHARE=/path     arm64 image: share this folder with the VM, read-write.
#                         It appears there as ~/Mac. Must be a folder inside your
#                         home directory or on an external volume.
#   BAMBO_STATE=out       where the VM disk, pid file and control socket live
#   BAMBO_DRY_RUN=1       print the QEMU command instead of running it
#   BAMBO_MEM=4096        RAM in MiB
#   BAMBO_CPUS=4
#   BAMBO_DISK=out/test-disk.qcow2   x86 only: blank disk for bambo-install (created if missing)
#   BAMBO_QEMU_EXTRA="..."           extra QEMU arguments
#
# Other commands, used by the Try BamboOS app (make app):
#   scripts/try-bambo.sh --info     image, VM disk and running state as key=value lines
#   scripts/try-bambo.sh --stop     ask the running VM to shut down cleanly
#   scripts/try-bambo.sh --kill     stop the running VM at once
#   scripts/try-bambo.sh --reset    delete the VM disk (the VM must be stopped)
#
# Leave: Ctrl+Option+G releases the keyboard, then Cmd+Q quits (Cmd+F leaves full screen).
set -euo pipefail

cd "$(dirname "$0")/.."

newest() { find out -maxdepth 1 -name "$1" -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n1 || true; }

os="$(uname -s)"
state="${BAMBO_STATE:-out}"
overlay="$state/try-arm64.qcow2" vars="$state/try-arm64-vars.fd"
pidfile="$state/try.pid" qmp="$state/try-qmp.sock"

# Pid of the running VM, or nothing.
vm_pid() {
  local pid
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then echo "$pid"; return; fi
  # A VM started by an older version of this script left no pid file.
  pgrep -f "qemu-system-.*file=$overlay," 2>/dev/null | head -n1 || true
}

# The image a VM disk was made for must be this exact build (see below).
image_stamp() { echo "$(realpath "$1") $(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1")"; }
file_size() { stat -f %z "$1" 2>/dev/null || stat -c %s "$1" 2>/dev/null || echo 0; }
file_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

# share_dir <path>: print the real path of a folder that is safe to share, or
# fail with the reason. The VM writes there as you, and agents inside the VM
# run without a sandbox, so the home folder itself and system folders are refused.
share_dir() {
  local dir="$1" real
  [[ $dir == /* ]] || { echo "the shared folder must be an absolute path." >&2; return 1; }
  [[ -d $dir ]] || { echo "the shared folder does not exist: $dir" >&2; return 1; }
  real="$(cd "$dir" && pwd -P)"
  case "$real" in
    "$HOME") echo "sharing the whole home folder is not allowed. Pick a folder inside it." >&2; return 1 ;;
    "$HOME"/Library | "$HOME"/Library/*) echo "sharing ~/Library is not allowed." >&2; return 1 ;;
    "$HOME"/.ssh | "$HOME"/.ssh/* | "$HOME"/.gnupg | "$HOME"/.gnupg/*) echo "sharing a folder with keys is not allowed." >&2; return 1 ;;
    "$HOME"/* | /Volumes/*/* | /private/tmp/* | /tmp/*) ;;
    *) echo "the shared folder must be inside your home folder or on an external volume: $real" >&2; return 1 ;;
  esac
  printf '%s\n' "$real"
}

case "${1:-}" in
  --stop)
    [[ -n $(vm_pid) ]] || { echo "try-bambo: no VM is running."; exit 0; }
    # Same as pressing the power button: the guest shuts down and QEMU exits.
    [[ -S $qmp ]] || { echo "try-bambo: this VM has no control socket. Shut it down from inside (Super + Escape)." >&2; exit 1; }
    (printf '{"execute":"qmp_capabilities"}\n{"execute":"system_powerdown"}\n'; sleep 1) | nc -U "$qmp" >/dev/null ||
      { echo "try-bambo: could not reach the VM's control socket $qmp." >&2; exit 1; }
    echo "try-bambo: asked the VM to shut down."
    exit 0 ;;
  --kill)
    pid="$(vm_pid)"
    [[ -n $pid ]] || { echo "try-bambo: no VM is running."; exit 0; }
    kill "$pid"
    echo "try-bambo: stopped the VM."
    exit 0 ;;
  --reset)
    [[ -z $(vm_pid) ]] || { echo "try-bambo: the VM is running. Stop it first." >&2; exit 1; }
    rm -f "$overlay" "$overlay.stamp" "$vars"
    echo "try-bambo: VM disk deleted. The next start uses a clean image."
    exit 0 ;;
  --info)
    image="$(newest 'bambo-os-*-aarch64.qcow2')"
    echo "image=$image"
    if [[ -n $image ]]; then
      echo "image_size=$(file_size "$image")"
      echo "image_mtime=$(file_mtime "$image")"
    fi
    if [[ -e $overlay ]]; then
      echo "disk_size=$(file_size "$overlay")"
      # "stale" means the image was rebuilt: the next start replaces the disk.
      if [[ -n $image && $(cat "$overlay.stamp" 2>/dev/null) == "$(image_stamp "$image")" ]]; then
        echo "disk=current"
      else
        echo "disk=stale"
      fi
    else
      echo "disk=none"
    fi
    echo "pid=$(vm_pid)"
    exit 0 ;;
  --*) echo "try-bambo: unknown option $1" >&2; exit 1 ;;
esac

[[ -z $(vm_pid) ]] || { echo "try-bambo: a VM is already running (pid $(vm_pid))." >&2; exit 1; }

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

mkdir -p "$state"
rm -f "$qmp"
args=(-name BamboOS -m "${BAMBO_MEM:-4096}" -smp "${BAMBO_CPUS:-4}"
  -device qemu-xhci -device usb-tablet
  -pidfile "$pidfile" -qmp "unix:$qmp,server=on,wait=off")

shared=""
if [[ -n ${BAMBO_SHARE:-} ]]; then
  if [[ $arch != aarch64 ]]; then
    echo "try-bambo: BAMBO_SHARE only works with the arm64 image. Not sharing a folder."
  else
    shared="$(share_dir "$BAMBO_SHARE")" || { echo "try-bambo: folder not shared, see above." >&2; exit 1; }
    # QEMU splits options at commas. A doubled comma is a literal one.
    args+=(-virtfs "local,path=${shared//,/,,},mount_tag=mac,security_model=none,multidevs=remap")
  fi
fi

if [[ $arch == aarch64 ]]; then
  [[ $os == Darwin && $(uname -m) == arm64 ]] || { echo "try-bambo: the arm64 image needs an Apple Silicon Mac." >&2; exit 1; }
  share="$(dirname "$(realpath "$(command -v "$qemu")")")/../share/qemu"
  code="$share/edk2-aarch64-code.fd"
  [[ -r $code && -r $share/edk2-arm-vars.fd ]] || { echo "try-bambo: UEFI firmware not found in $share." >&2; exit 1; }
  mkdir -p "$state"
  # The VM disk is an overlay on one image and is only valid for that exact
  # build. The stamp records which one: file times alone do not work, because a
  # running VM keeps the overlay newer than any image built meanwhile.
  stamp="$(image_stamp "$media")"
  if [[ ! -e $overlay || $(cat "$overlay.stamp" 2>/dev/null) != "$stamp" ]]; then
    echo "try-bambo: new VM disk $overlay on top of $media"
    rm -f "$overlay" "$vars"
    qemu-img create -q -f qcow2 -F qcow2 -b "$(realpath "$media")" "$overlay"
    echo "$stamp" >"$overlay.stamp"
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

if [[ $os == Darwin ]]; then
  # Sound through the Mac's output device. Output only: a duplex codec would
  # make macOS ask for the microphone.
  args+=(-audiodev "coreaudio,id=snd" -device intel-hda -device "hda-output,audiodev=snd")
  # Clipboard: a virtio port in the guest, a unix socket here, and a helper
  # that keeps the socket and the macOS pasteboard in step. BAMBO_CLIPBOARD=0 turns it off.
  if [[ ${BAMBO_CLIPBOARD:-1} == 1 ]] && command -v python3 >/dev/null 2>&1; then
    clip="${TMPDIR:-/tmp}/bambo-clipboard-$$.sock"
    args+=(-device virtio-serial-pci
      -chardev "socket,id=clip,path=$clip,server=on,wait=off"
      -device "virtserialport,chardev=clip,name=org.bambo.clipboard")
    [[ ${BAMBO_DRY_RUN:-0} == 1 ]] || python3 "$(dirname "$0")/clipboard-host.py" "$clip" &
  fi
fi

# full-grab sends Cmd+Space, Cmd+Tab and friends to the guest. It needs the
# Accessibility permission for the app that starts QEMU and is skipped without it.
echo "try-bambo: $media ($arch) at ${xres}x${yres}, full screen $full"
[[ -z $shared ]] || echo "try-bambo: sharing $shared with the VM as ~/Mac"
if [[ ${BAMBO_DRY_RUN:-0} == 1 ]]; then
  printf '%q ' "$qemu" "${args[@]}"; printf '\n'
  exit 0
fi
# shellcheck disable=SC2086
exec "$qemu" "${args[@]}" ${BAMBO_QEMU_EXTRA:-}
