#!/usr/bin/env bash
# smoke-test.sh <iso> [live|install]: boot BamboOS in QEMU without a display and
# check it from the outside. The guest reports through serial-port markers
# written by bambo-smoke. Screenshots come from the QEMU monitor.
#
#   live     boot the ISO, check desktop, terminal, screenshot, recording, browser
#   install  boot the ISO, run bambo-install unattended on a blank virtual disk,
#            then boot that disk and check the installed desktop (BIOS/GRUB path)
#
# Output goes to out/smoke/ (or $BAMBO_SMOKE_DIR).
set -euo pipefail

iso="${1:?usage: smoke-test.sh <iso> [live|install]}"
mode="${2:-live}"
outdir="${BAMBO_SMOKE_DIR:-out/smoke}"
port=45454
mkdir -p "$outdir"

accel=(-accel tcg)
[[ -w /dev/kvm ]] && accel=(-accel kvm -cpu host)

qemu=""
trap '[[ -n $qemu ]] && kill "$qemu" 2>/dev/null || true' EXIT

monitor() {
  exec 3<>"/dev/tcp/127.0.0.1/$port"
  printf '%s\n' "$1" >&3
  sleep 2
  exec 3>&- 3<&-
}

# boot <name> <timeout seconds> <qemu args...>
# Runs until the guest writes BAMBO_SMOKE_DONE, powers off, or the timeout hits.
boot() {
  local name="$1" limit="$2" result='timed out'
  shift 2
  log="$outdir/$name.log"
  : >"$log"
  rm -f "$outdir/$name.png" "$outdir/$name-terminal.png"

  qemu-system-x86_64 "${accel[@]}" -m 4096 -smp 2 \
    -vga virtio -display none \
    -serial "file:$log" \
    -monitor "tcp:127.0.0.1:$port,server,nowait" \
    -no-reboot "$@" &
  qemu=$!

  for ((i = 0; i < limit; i++)); do
    kill -0 "$qemu" 2>/dev/null || { result='qemu exited'; break; }
    if [[ ! -f $outdir/$name-terminal.png ]] && grep -q BAMBO_TERMINAL "$log"; then
      sleep 1
      monitor "screendump $outdir/$name-terminal.png -f png" || true
    fi
    if grep -q BAMBO_SMOKE_DONE "$log"; then result='finished'; break; fi
    sleep 1
  done

  monitor "screendump $outdir/$name.png -f png" || true
  kill "$qemu" 2>/dev/null || true
  wait "$qemu" 2>/dev/null || true
  qemu=""

  echo "---- $name: $result ----"
  grep -a 'BAMBO_\|LOG:' "$log" || true
  echo "------------------------"
}

need() {
  grep -q "$1" "$log" || { echo "FAIL: $2"; exit 1; }
}

case "$mode" in
  live)
    boot live 420 -cdrom "$iso" -boot d -smbios type=11,value=bambo-smoke-full
    need BAMBO_LIVE_READY "live system did not boot"
    need BAMBO_DESKTOP_READY "Hyprland did not start"
    need 'BAMBO_WAYBAR=up' "waybar is not running"
    need 'BAMBO_TERMINAL=up' "terminal did not open"
    need 'BAMBO_SCREENSHOT=ok' "bambo-shot saved no file"
    need 'BAMBO_RECORDING=ok' "bambo-record saved no file"
    need 'BAMBO_BROWSER=up' "browser did not start"
    echo "PASS: live desktop is up, terminal, screenshot, recording and browser work"
    ;;
  install)
    disk="$outdir/disk.qcow2"
    rm -f "$disk"
    qemu-img create -q -f qcow2 "$disk" 24G
    drive=(-drive "file=$disk,if=virtio,format=qcow2")

    boot install 1800 -cdrom "$iso" -boot d "${drive[@]}" -smbios type=11,value=bambo-smoke-install
    need 'BAMBO_INSTALL=ok' "bambo-install failed"

    boot installed 300 "${drive[@]}" -boot c
    need BAMBO_LIVE_READY "installed system did not boot"
    need BAMBO_DESKTOP_READY "Hyprland did not start on the installed system"
    need 'BAMBO_WAYBAR=up' "waybar is not running on the installed system"
    rm -f "$disk"
    echo "PASS: bambo-install works and the installed system boots to the desktop"
    ;;
  *)
    echo "unknown mode: $mode" >&2
    exit 2
    ;;
esac
