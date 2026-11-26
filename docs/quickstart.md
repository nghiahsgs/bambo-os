# Quickstart

## Build the ISO

Requirements: Arch Linux with `archiso`, or any machine with Docker.

```bash
make iso
```

Output: `out/bambo-os-<date>-x86_64.iso`, a `.sha256` file and `build-report.txt` (ISO size, package count).

On Apple Silicon the Docker build runs under x86 emulation and is slow. Use the CI artifact instead.

## Flash a USB stick

Linux and macOS:

```bash
sudo dd if=out/bambo-os-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Check the device name with `lsblk` (Linux) or `diskutil list` (macOS) first. Windows: use Rufus in DD mode.

Verify the download:

```bash
sha256sum -c bambo-os-*.iso.sha256
```

## Boot

- Turn **Secure Boot off** in the firmware.
- UEFI and legacy BIOS both work.
- NVIDIA GPUs are not supported in v0.1. Intel and AMD graphics are.

## Try it in a VM

Linux with KVM:

```bash
make test-vm
```

This attaches a 32 GB virtual disk, so you can also test `bambo-install`.

Other hypervisors: give the VM at least 4 GB RAM and enable 3D acceleration. Hyprland needs working OpenGL. Without acceleration it falls back to software rendering, which is slow.

## Install to disk

```bash
bambo-install
```

1. Pick the disk. The live USB is never offered.
2. Hostname, username, password.
3. Type the disk name to confirm. Nothing is touched before this point.
4. Wait. The installer downloads about 1.2 GB of packages.
5. Reboot. You are logged in automatically on tty1 and Hyprland starts.

Layout: GPT, ext4 root, GRUB. UEFI machines get a 1 GB EFI partition mounted at `/boot`.

After install:

- Time zone is UTC. Change it: `sudo timedatectl set-timezone Asia/Ho_Chi_Minh`
- Auto-login is on. Turn it off: `sudo rm /etc/systemd/system/getty@tty1.service.d/autologin.conf`
- Google Chrome instead of Chromium: install `google-chrome` from the AUR.
- Update: `update` (alias for `sudo pacman -Syu`)

## Change the look

Edit the files in `~/.config`. The palette is listed in `themes/tessera/tokens.md`. Hyprland reloads its config on save. Restart waybar with `pkill waybar; waybar &`.
