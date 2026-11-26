#!/usr/bin/env bash
# shellcheck disable=SC2034
# BamboOS archiso profile. Based on the upstream "releng" profile (archiso 92).

iso_name="bambo-os"
iso_label="BAMBO_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="BamboOS <https://github.com/nghiahsgs/bambo-os>"
iso_application="BamboOS Live/Install"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="bambo"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# zstd: boots faster than xz and builds much faster, costs ~10% size.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/00-live-wheel"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/bambo-install"]="0:0:755"
  ["/usr/local/bin/bambo-agent"]="0:0:755"
  ["/usr/local/bin/bambo-keys"]="0:0:755"
  ["/usr/local/bin/bambo-power"]="0:0:755"
  ["/usr/local/bin/bambo-shot"]="0:0:755"
  ["/usr/local/bin/bambo-record"]="0:0:755"
  ["/usr/local/bin/bambo-smoke"]="0:0:755"
  ["/usr/local/bin/bambo-fetch"]="0:0:755"
)
