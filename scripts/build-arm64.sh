#!/usr/bin/env bash
# build-arm64.sh: build a ready-to-boot BamboOS disk image for arm64 (Apple
# Silicon Macs under QEMU + HVF, see scripts/try-bambo.sh).
#
#   scripts/build-arm64.sh          on the host: build the builder container, run the build in it
#   scripts/build-arm64.sh inside   in the container (privileged): build the image
#
# Unlike the x86 ISO this is not a live medium. It is an installed system:
# Arch Linux ARM + the BamboOS package set and dotfiles, user "bambo" with an
# empty password, auto-login on tty1. Output: out/bambo-os-<date>-aarch64.qcow2
#
# Env: BAMBO_OUT_DIR (default ./out), BAMBO_IMAGE_GIB (virtual disk size, default 16),
# BAMBO_UID (uid of the VM user, default: the uid of the user running the build).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ${1:-} != inside ]]; then
  command -v docker >/dev/null || { echo "build-arm64.sh: docker is required." >&2; exit 1; }
  out="${BAMBO_OUT_DIR:-$repo/out}"
  # The VM user gets the uid of whoever builds the image, so a folder shared
  # from this machine is writable in the VM (see scripts/bambo-share).
  host_uid="$(id -u)"
  ((host_uid >= 500)) || host_uid=1000
  mkdir -p "$out"
  docker build --platform linux/arm64 -f "$repo/arm64/Containerfile" -t bambo-arm64-builder "$repo/arm64"
  docker volume create bambo-arm64-work >/dev/null
  docker volume create bambo-arm64-pkgcache >/dev/null
  exec docker run --rm --platform linux/arm64 --privileged \
    -v "$repo:/src:ro" -v "$out:/out" \
    -v bambo-arm64-work:/work -v bambo-arm64-pkgcache:/var/cache/pacman/pkg \
    -e BAMBO_IMAGE_GIB="${BAMBO_IMAGE_GIB:-16}" \
    -e BAMBO_UID="${BAMBO_UID:-$host_uid}" \
    bambo-arm64-builder /src/scripts/build-arm64.sh inside
fi

# ---- inside the container -----------------------------------------------------

size_gib="${BAMBO_IMAGE_GIB:-16}"
disk=/work/bambo.img
target=/work/root
esp_loop="" root_loop=""

cleanup() {
  mountpoint -q "$target" && umount -R "$target" 2>/dev/null || true
  [[ -z $esp_loop ]] || losetup -d "$esp_loop" 2>/dev/null || true
  [[ -z $root_loop ]] || losetup -d "$root_loop" 2>/dev/null || true
}
trap cleanup EXIT

step() { printf '==> %s\n' "$*"; }

list() { grep -hv '^\s*#' "$@" | sed '/^\s*$/d'; }
mapfile -t packages < <(
  { list /src/iso/packages.x86_64 | grep -vxFf <(list /src/arm64/packages.exclude); list /src/arm64/packages.extra; } | sort -u
)

step "Checking that the Arch Linux ARM repositories carry all ${#packages[@]} packages"
pacman -Sy >/dev/null
missing=()
for p in "${packages[@]}"; do
  pacman -Si "$p" >/dev/null 2>&1 || missing+=("$p")
done
((${#missing[@]} == 0)) || { echo "build-arm64.sh: not in the arm64 repositories: ${missing[*]}" >&2; exit 1; }

step "Creating a ${size_gib} GiB disk image"
rm -f "$disk"
mkdir -p "$target"
truncate -s "${size_gib}G" "$disk"
# The root partition uses the "Linux root (ARM-64)" type.
sfdisk --quiet "$disk" <<'PARTS'
label: gpt
size=512MiB, type=uefi, name=BAMBOESP
type=b921b045-1df0-41c3-af44-4c6f280d3fae, name=bambo-root
PARTS

# Loop devices by offset: partition nodes do not appear inside a container.
part_field() { sfdisk --json "$disk" | jq -r --argjson n "$1" --arg f "$2" '.partitiontable.partitions[$n][$f]'; }
esp_start="$(part_field 0 start)" esp_size="$(part_field 0 size)"
root_start="$(part_field 1 start)" root_size="$(part_field 1 size)"
esp_loop="$(losetup --find --show --offset $((esp_start * 512)) --sizelimit $((esp_size * 512)) "$disk")"
root_loop="$(losetup --find --show --offset $((root_start * 512)) --sizelimit $((root_size * 512)) "$disk")"
mkfs.vfat -F 32 -n BAMBOESP "$esp_loop" >/dev/null
mkfs.ext4 -q -F -L bambo "$root_loop"
mount "$root_loop" "$target"
mount --mkdir -o umask=0077 "$esp_loop" "$target/boot"

# The initramfs must not depend on the build host: no autodetect, and the
# virtio drivers a VM needs are named explicitly.
install -D -m 644 /dev/stdin "$target/etc/mkinitcpio.conf.d/bambo.conf" <<'CONF'
MODULES=(virtio_pci virtio_blk virtio_scsi virtio_gpu virtio_input ext4 nvme xhci_pci usbhid)
HOOKS=(base udev modconf kms keyboard keymap block filesystems fsck)
CONF

step "Installing ${#packages[@]} packages"
# -G: no host keyring, -M: no host mirrorlist, -c: use the host package cache.
pacstrap -G -M -c "$target" "${packages[@]}"

step "Configuring the system"
arch-chroot "$target" pacman-key --init >/dev/null 2>&1
arch-chroot "$target" pacman-key --populate archlinuxarm >/dev/null 2>&1
cat >"$target/etc/fstab" <<'FSTAB'
LABEL=bambo     /      ext4  rw,relatime        0 1
LABEL=BAMBOESP  /boot  vfat  rw,umask=0077      0 2
FSTAB
echo bambo >"$target/etc/hostname"
printf '127.0.0.1 localhost\n::1       localhost\n127.0.1.1 bambo\n' >"$target/etc/hosts"
sed -i 's/^#\(en_US\.UTF-8 UTF-8\)/\1/' "$target/etc/locale.gen"
echo 'LANG=en_US.UTF-8' >"$target/etc/locale.conf"
arch-chroot "$target" locale-gen >/dev/null
ln -sf /usr/share/zoneinfo/UTC "$target/etc/localtime"

# shellcheck source=scripts/lib-assemble.sh
source /src/scripts/lib-assemble.sh
bambo_assemble_root /src "$target"
rm -f "$target/usr/local/bin/bambo-smoke" "$target/usr/local/bin/bambo-install"

# Arch Linux ARM has no openai-codex package, so Codex comes from npm here.
# Claude Code is in no Arch repository, so it comes from npm too. Its native
# binary arrives in an install script, which npm only runs when allowed by name.
# Pi is the third agent, also only on npm. Its command is "pi".
# A failed download must not fail the image: bambo-codex says how to install it.
step "Installing Codex, Claude Code and Pi from npm"
for agent in @openai/codex @anthropic-ai/claude-code @earendil-works/pi-coding-agent; do
  arch-chroot "$target" npm install --global --prefix /usr/local --no-fund --no-audit \
    --allow-scripts="$agent" "$agent" ||
    echo "warning: $agent was not installed (npm failed)."
done

# Same account as the live ISO: "bambo", empty password, sudo without a prompt.
arch-chroot "$target" userdel -r alarm >/dev/null 2>&1 || true
arch-chroot "$target" useradd -m -u "${BAMBO_UID:-1000}" -G wheel,docker -s /usr/bin/zsh bambo
arch-chroot "$target" passwd -d bambo >/dev/null
# systemd treats a uid below 1000 as a system account and gives its logins a
# "user-light" session: no user service manager, so no session bus, no mako and
# no PipeWire. A Mac user is uid 501, so ask for a full session by name.
if (( ${BAMBO_UID:-1000} < 1000 )); then
  sed -i -E 's/^(-?session[[:space:]]+optional[[:space:]]+pam_systemd\.so).*/\1 class=user/' "$target/etc/pam.d/system-login"
  grep -q 'pam_systemd.so class=user' "$target/etc/pam.d/system-login" ||
    echo "warning: could not set the session class. Notifications and sound may not work."
fi
arch-chroot "$target" passwd -l root >/dev/null
install -m 440 /dev/stdin "$target/etc/sudoers.d/10-wheel" <<'SUDO'
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
SUDO
for tty in getty@tty1 serial-getty@ttyAMA0; do
  install -D -m 644 /dev/stdin "$target/etc/systemd/system/$tty.service.d/autologin.conf" <<'UNIT'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --autologin bambo - ${TERM}
UNIT
done
arch-chroot "$target" systemctl enable NetworkManager.service systemd-timesyncd.service docker.socket >/dev/null 2>&1

# Download the Neovim plugins now, so the first start is instant and works offline.
# Language servers and parsers still install on first use. Failure is not fatal.
step "Downloading the Neovim plugins"
arch-chroot -u bambo "$target" env HOME=/home/bambo nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 ||
  echo "warning: Neovim plugins were not downloaded. They install on the first start."

step "Installing the bootloader (systemd-boot at the removable path)"
# A new VM has an empty variable store, so the firmware only finds EFI/BOOT/BOOTAA64.EFI.
install -D -m 644 "$target/usr/lib/systemd/boot/efi/systemd-bootaa64.efi" "$target/boot/EFI/BOOT/BOOTAA64.EFI"
install -D -m 644 /dev/stdin "$target/boot/loader/loader.conf" <<'LOADER'
default bambo.conf
timeout 0
LOADER
install -D -m 644 /dev/stdin "$target/boot/loader/entries/bambo.conf" <<'ENTRY'
title   BamboOS
linux   /Image
initrd  /initramfs-linux.img
options root=PARTLABEL=bambo-root rw quiet console=ttyAMA0 console=tty1
ENTRY
[[ -s $target/boot/Image && -s $target/boot/initramfs-linux.img ]] || { echo "build-arm64.sh: kernel or initramfs missing in /boot" >&2; ls -la "$target/boot" >&2; exit 1; }

pkgs="$(find "$target/var/lib/pacman/local" -mindepth 1 -maxdepth 1 -type d | wc -l)"
used_mb="$(df -m --output=used "$target" | tail -n1 | tr -d ' ')"

step "Writing the image"
sync
umount -R "$target"
losetup -d "$esp_loop" "$root_loop"
esp_loop="" root_loop=""
name="bambo-os-$(date +%Y.%m.%d)-aarch64.qcow2"
qemu-img convert -O qcow2 -c "$disk" "/out/$name.part"
mv "/out/$name.part" "/out/$name"
rm -f "$disk"
(cd /out && sha256sum "$name" >"$name.sha256")
{
  echo "image=$name"
  echo "image_size_mb=$(($(stat -c %s "/out/$name") / 1024 / 1024))"
  echo "installed_packages=$pkgs"
  echo "installed_size_mb=$used_mb"
} | tee /out/build-report-arm64.txt
