#!/usr/bin/env bash
# verify-hypr.sh: let Hyprland itself parse config/hypr without starting a session.
# Hyprland refuses to run as root, so the check runs as an unprivileged user.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.config" "$tmp/run"
cp -r "$repo/config/hypr" "$tmp/home/.config/hypr"
chmod -R a+rX "$tmp"
chmod 700 "$tmp/run"

run=(env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_RUNTIME_DIR="$tmp/run"
  Hyprland --verify-config --config "$tmp/home/.config/hypr/hyprland.lua")
if [[ $EUID -eq 0 ]]; then
  chown -R nobody "$tmp"
  out="$(runuser -u nobody -- "${run[@]}" 2>&1)" && rc=0 || rc=$?
else
  out="$("${run[@]}" 2>&1)" && rc=0 || rc=$?
fi
printf '%s\n' "$out" | tail -n 30
if [[ $rc -ne 0 ]] || grep -qiE 'config (has )?error|error in|\[ ERROR \]' <<<"$out"; then
  echo "verify-hypr: Hyprland reported config problems (exit $rc)" >&2
  exit 1
fi
echo "verify-hypr: ok"
