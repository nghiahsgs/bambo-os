#!/usr/bin/env bash
# lib-assemble.sh: put the BamboOS dotfiles, tools and shared data into a root
# tree. Sourced by build-iso.sh (archiso airootfs) and build-arm64.sh (disk image).
#
#   bambo_assemble_root <repo> <root>
#
# config/ is the single source of truth for dotfiles. It lands in /etc/skel.

bambo_assemble_root() {
  local repo="$1" root="$2" dir tool
  local skel="$root/etc/skel" bin="$root/usr/local/bin" share="$root/usr/share/bambo"

  mkdir -p "$skel/.config" "$bin" "$share/tessera"
  for dir in hypr kitty waybar rofi mako mpv tmux bambo fontconfig; do
    cp -a "$repo/config/$dir" "$skel/.config/"
  done
  cp "$repo/config/starship.toml" "$skel/.config/starship.toml"
  cp "$repo/config/chromium-flags.conf" "$skel/.config/chromium-flags.conf"
  cp "$repo/config/zshrc" "$skel/.zshrc"
  cp "$repo/config/zprofile" "$skel/.zprofile"

  for tool in "$repo"/scripts/bambo-*; do
    install -m 755 "$tool" "$bin/"
  done
  cp "$repo/themes/tessera/wallpaper.png" "$repo/themes/tessera/logo.svg" "$share/tessera/"
  cp "$repo/iso/packages.x86_64" "$share/packages.x86_64"
}
