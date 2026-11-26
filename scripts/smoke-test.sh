#!/usr/bin/env bash
# smoke-test.sh <iso>: boot the ISO in QEMU without a display and check that the
# live desktop comes up. Reads the markers that bambo-smoke writes to the serial
# port, then takes a screenshot through the QEMU monitor.
#
# Output: out/smoke/serial.log, out/smoke/screenshot.png
set -euo pipefail

iso="${1:?usage: smoke-test.sh <iso>}"
outdir="${BAMBO_SMOKE_DIR:-out/smoke}"
timeout_s="${BAMBO_SMOKE_TIMEOUT:-420}"
port=45454
mkdir -p "$outdir"
log="$outdir/serial.log"
: >"$log"

accel=(-accel tcg)
[[ -w /dev/kvm ]] && accel=(-accel kvm -cpu host)

qemu-system-x86_64 "${accel[@]}" -m 4096 -smp 2 \
  -cdrom "$iso" -boot d \
  -vga virtio -display none \
  -serial "file:$log" \
  -monitor "tcp:127.0.0.1:$port,server,nowait" \
  -no-reboot &
qemu=$!
trap 'kill $qemu 2>/dev/null || true' EXIT

monitor() {
  exec 3<>"/dev/tcp/127.0.0.1/$port"
  printf '%s\n' "$1" >&3
  sleep 2
  exec 3>&- 3<&-
}

result='timed out'
for ((i = 0; i < timeout_s; i++)); do
  kill -0 "$qemu" 2>/dev/null || { result='qemu exited'; break; }
  if grep -q BAMBO_SMOKE_DONE "$log"; then result='finished'; break; fi
  sleep 1
done

monitor "screendump $outdir/screenshot.png -f png" || true

echo "---- markers ----"
grep -a 'BAMBO_\|LOG:' "$log" || true
echo "-----------------"
echo "result: $result"

grep -q BAMBO_LIVE_READY "$log" || { echo "FAIL: live system did not boot"; exit 1; }
grep -q BAMBO_DESKTOP_READY "$log" || { echo "FAIL: Hyprland did not start"; exit 1; }
grep -q 'BAMBO_WAYBAR=up' "$log" || { echo "FAIL: waybar is not running"; exit 1; }
echo "PASS: live desktop is up"
