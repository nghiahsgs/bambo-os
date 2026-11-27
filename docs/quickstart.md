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

### Apple Silicon Mac: the arm64 image (fast)

An Apple Silicon Mac cannot run the x86 ISO at a usable speed. Build the arm64 image instead. It runs at native CPU speed through Apple's Hypervisor framework and reaches the desktop in about 10 seconds.

```bash
brew install qemu
```

```bash
make arm64
```

```bash
make try
```

- `make arm64` needs Docker. It builds `out/bambo-os-<date>-aarch64.qcow2` (about 1.9 GB) from the Arch Linux ARM repositories with the same package list and dotfiles as the ISO.
- The image is an installed system, not a live medium. User `bambo`, empty password, `sudo` without a prompt. There is no `bambo-install` in it.
- `make try` opens it full screen. The arm64 guest gets one mode with the pixel size of your main display (3024x1964 on a 14 inch MacBook Pro) and BamboOS scales it 2x, so text is sharp. Drawing is done by the CPU, so if it feels slow, halve it with `BAMBO_RES=1512x982`. Other settings: `BAMBO_WINDOWED=1`, `BAMBO_MEM`, `BAMBO_CPUS`.
- Your changes live in `out/try-arm64.qcow2`. Delete it to start clean. Rebuilding the image also resets it.
- Graphics are software-rendered. Stock QEMU on macOS has no GPU acceleration for Linux guests.
- Command is `Super` inside the VM.
- macOS keeps `Cmd + Space` and `Cmd + Tab` for itself unless the app that starts QEMU (Terminal, for example) has the Accessibility permission in System Settings, Privacy & Security.
- Leave: `Ctrl + Option + G` releases the keyboard, then `Cmd + Q` quits. `Cmd + F` leaves full screen.
- The launcher is rofi 1.7.5 through XWayland here, because Arch Linux ARM does not carry rofi 2 yet.

### Mac with the x86 ISO

`scripts/try-bambo.sh out/bambo-os-*.iso` boots the ISO full screen. An Intel Mac uses the hypervisor and is fast. Apple Silicon emulates the x86 CPU: about 9 minutes to the desktop on an M5, and slow enough that parts of the desktop can fail to start.

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
