# BamboOS

A minimal Arch Linux spin that looks right out of the box and ships only what a developer needs: a good terminal, a browser, a video player and screen capture. Everything is driven from the keyboard, in the style of Omarchy.

BamboOS is the bicycle of Linux distros: light, simple, nothing extra.

- **No desktop environment.** Hyprland (tiling Wayland compositor) only.
- **Four tool groups.** Terminal (kitty), browser (Chromium), media (mpv), capture (grim, slurp, wf-recorder).
- **Keyboard first.** `Super` is the centre. The mouse is optional.
- **One look.** The "Tessera" design language: charcoal, hairline borders, Inter and JetBrains Mono, blue / orange / green accents.
- **Agent ready.** Docker, Node LTS, Python + uv and tmux are preinstalled. `bambo-agent on` turns the machine into a headless box for AI coding agents.
- **Plain Arch underneath.** No forked packages, no extra repo. `pacman -Syu` updates it.

Status: v0.1, early. See [Status](#status) for what is verified and what is not.

## Try it in 5 minutes

1. Get the ISO. Either download the `bambo-os-iso` artifact from the latest green run under the Actions tab, or build it yourself:

   ```bash
   make iso
   ```

   On Arch this runs `mkarchiso` directly. Elsewhere it uses Docker. The ISO lands in `out/`.

2. Flash it to a USB stick (replace `/dev/sdX`, this erases the stick):

   ```bash
   sudo dd if=out/bambo-os-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```

   Or boot it in a VM: `make test-vm` (Linux with KVM).

3. Boot. Turn Secure Boot off in the firmware first. You land in the desktop with no password.

4. Press `Super + /` to see every shortcut. `Super + Enter` opens a terminal.

5. To keep it, click **Install BamboOS** in the top bar or run:

   ```bash
   bambo-install
   ```

   It asks for disk, hostname, username and password, then wipes the disk and installs. It needs an internet connection (`nmtui` for Wi-Fi).

More detail: [docs/quickstart.md](docs/quickstart.md).

## Keyboard

- `Super + Enter`: terminal
- `Super + B`: browser
- `Super + Space`: app launcher
- `Super + Q`: close window
- `Super + F`: fullscreen
- `Super + V`: toggle floating / tiling
- `Super + 1..9`: switch workspace
- `Super + Shift + 1..9`: move window to workspace
- `Super + H / J / K / L`: move focus
- `Super + Shift + H / J / K / L`: swap window position
- `Super + Shift + S`: screenshot a region, saved to `~/Pictures` and copied
- `Super + Shift + R`: start / stop screen recording, saved to `~/Videos`, red dot in the bar while recording
- `Super + Escape`: lock screen
- `Super + Shift + E`: power menu
- `Super + /`: cheat sheet

## What is in the box

- Base: Arch Linux (rolling), `linux` kernel, NetworkManager, PipeWire
- Desktop: Hyprland, waybar (top bar and dock), rofi, mako, hyprlock
- Tools: kitty, Chromium, mpv, grim, slurp, wf-recorder
- Shell: zsh, starship, tmux, neovim, git, ripgrep, fzf, jq, btop
- Agent runtimes: Docker, Node.js LTS, Python, uv
- Commands: `bambo-install`, `bambo-agent`, `bambo-keys`, `bambo-shot`, `bambo-record`, `bambo-power`, `bambo-fetch`

The full list is [iso/packages.x86_64](iso/packages.x86_64). There is no settings app. Every setting is a text file in [config/](config/), copied to `~/.config` for new users.

## Repo layout

```
iso/                archiso profile (based on upstream releng)
  packages.x86_64   packages installed to disk
  packages.live     extra packages only the live ISO needs
  airootfs/         files overlaid on the live root filesystem
config/             dotfiles, the single source of truth (lands in /etc/skel)
scripts/            bambo-* commands, build-iso.sh, smoke-test.sh, verify-hypr.sh
themes/tessera/     design tokens, logo, wallpaper generator
docs/               quickstart, agent mode, decisions, PRD
Makefile            make iso / lint / test-vm / smoke
```

## Agent mode

```bash
bambo-agent on
```

No desktop on the next login, `sshd` and Docker enabled, a long-running tmux session named `agents`. See [docs/agent-mode.md](docs/agent-mode.md).

## Status

Verified in CI on every push (see the Actions tab):

- Shell scripts pass `shellcheck`, Lua passes `luac`
- Hyprland itself parses the config (`Hyprland --verify-config`)
- `make iso` builds, the ISO boots in QEMU and the live desktop starts (serial markers from `bambo-smoke`)

Not verified yet:

- `bambo-install` end to end on a clean VM
- Screenshot, recording and browser launch inside a real session
- Idle RAM and boot time on real hardware

Known gaps against the v0.1 targets:

- Package count is about 550 with dependencies. The 250 target is not reachable with Chromium, Hyprland and Docker in the set.
- No NVIDIA support, no Secure Boot, no disk encryption.
- The installer needs the network (it uses `pacstrap`).

Design choices and their reasons are in [docs/decisions.md](docs/decisions.md).

## License

GPL-3.0-or-later. The `iso/` profile is derived from the archiso `releng` profile.
