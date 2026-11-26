#!/usr/bin/env bash
# build-iso.sh: assemble the archiso profile from this repo and run mkarchiso.
# Must run as root on Arch Linux (or in an archlinux container, see the Makefile).
#
#   scripts/build-iso.sh            build out/bambo-os-<date>-x86_64.iso
#   scripts/build-iso.sh assemble   only assemble the profile (no root needed)
#
# Env: BAMBO_BUILD_DIR (default /var/tmp/bambo-build), BAMBO_OUT_DIR (default ./out),
#      BAMBO_DISABLE_SANDBOX=1 (needed when pacman runs under CPU emulation).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="${BAMBO_BUILD_DIR:-/var/tmp/bambo-build}"
out="${BAMBO_OUT_DIR:-$repo/out}"
profile="$build/profile"
work="$build/work"
mode="${1:-iso}"

echo "==> Assembling profile in $profile"
rm -rf "$profile"
mkdir -p "$profile"
cp -a "$repo/iso/." "$profile/"

# Package list for the ISO = installed set + live-only extras.
grep -hv '^\s*#' "$repo/iso/packages.x86_64" "$repo/iso/packages.live" | sed '/^\s*$/d' | sort -u >"$profile/packages.x86_64"
rm -f "$profile/packages.live"

# config/ is the single source of truth for dotfiles. It lands in /etc/skel.
skel="$profile/airootfs/etc/skel"
mkdir -p "$skel/.config"
for dir in hypr kitty waybar rofi mako mpv tmux bambo fontconfig; do
  cp -a "$repo/config/$dir" "$skel/.config/"
done
cp "$repo/config/starship.toml" "$skel/.config/starship.toml"
cp "$repo/config/chromium-flags.conf" "$skel/.config/chromium-flags.conf"
cp "$repo/config/zshrc" "$skel/.zshrc"
cp "$repo/config/zprofile" "$skel/.zprofile"

# Tools and shared data.
bin="$profile/airootfs/usr/local/bin"
share="$profile/airootfs/usr/share/bambo"
mkdir -p "$bin" "$share/tessera" "$profile/airootfs/usr/share/applications"
for tool in "$repo"/scripts/bambo-*; do
  install -m 755 "$tool" "$bin/"
done
cp "$repo/themes/tessera/wallpaper.png" "$repo/themes/tessera/logo.svg" "$share/tessera/"
cp "$repo/iso/packages.x86_64" "$share/packages.x86_64"
cat >"$profile/airootfs/usr/share/applications/bambo-install.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install BamboOS
Comment=Install BamboOS to a disk
Exec=kitty -e bambo-install
Terminal=false
Categories=System;
DESKTOP

if [[ ${BAMBO_DISABLE_SANDBOX:-0} == 1 ]]; then
  sed -i 's/^\[options\]/[options]\nDisableSandbox/' "$profile/pacman.conf"
fi

[[ $mode == assemble ]] && { echo "==> Profile ready: $profile"; exit 0; }

[[ $EUID -eq 0 ]] || { echo "build-iso.sh: mkarchiso needs root." >&2; exit 1; }
command -v mkarchiso >/dev/null || { echo "build-iso.sh: install the 'archiso' package first." >&2; exit 1; }

echo "==> Running mkarchiso"
rm -rf "$work"
mkdir -p "$out"
mkarchiso -v -w "$work" -o "$out" "$profile"

# shellcheck disable=SC2012
iso="$(ls -t "$out"/bambo-os-*.iso | head -n1)"
(cd "$out" && sha256sum "$(basename "$iso")" >"$(basename "$iso").sha256")
pkgs="$(find "$work/x86_64/airootfs/var/lib/pacman/local" -mindepth 1 -maxdepth 1 -type d | wc -l)"
size_mb="$(($(stat -c %s "$iso") / 1024 / 1024))"
{
  echo "iso=$(basename "$iso")"
  echo "iso_size_mb=$size_mb"
  echo "live_packages=$pkgs"
} | tee "$out/build-report.txt"
rm -rf "$work"
