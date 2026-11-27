# Decisions for v0.1

Short record of choices made while implementing the PRD ([PRD.md](PRD.md)), with the reason for each.

## Open questions from the PRD

- **Terminal: kitty.** Most complete, in the official repos, ligatures work by default.
- **Browser: Chromium.** It is in the official repos. Chrome comes from the AUR, which means a build step and a helper. Docs explain how to add Chrome later.
- **Launcher: rofi.** `walker` is not in the official repos. `rofi-wayland` was merged into `rofi` (2.x), which now runs natively on Wayland. The same binary draws the power menu and the cheat sheet, so no extra package.
- **Display manager: none.** Auto-login on tty1, then `~/.zprofile` starts Hyprland.
- **Containers: Docker**, enabled by socket activation so it costs nothing while idle.
- **Node: `nodejs-lts-krypton` from the repos**, not nvm. One version, updated by pacman.
- **NVIDIA, Secure Boot, encryption:** out of scope for v0.1, as the PRD says.

## Things the PRD did not foresee

- **Hyprland config is Lua.** The Hyprland in the Arch repos (0.57) uses `hyprland.lua` and the `hl.*` API. The config lives in `config/hypr/*.lua`. CI runs `Hyprland --verify-config` on it.
- **Keys follow Omarchy, not the PRD table.** Where the two disagree, Omarchy wins, so people who know it have nothing to relearn. Close is `Super + W` (and `Q`). Focus is `Super + Arrows`, not `H/J/K/L`. Float is `Super + T`, because `Super + C / V / X / A` are copy, paste, cut and select all. The cheat sheet is `Super + K`. `Super + Escape` is the power menu, and lock is in that menu and on `Super + Ctrl + L`. BamboOS keeps its own chord only where Omarchy has none for the feature: `Super + Shift + S` and `Super + Shift + R` for capture, `Super + Shift + A` for Codex.
- **A file manager and Codex are in the set.** yazi is the file manager: it runs in the terminal and adds one package. Codex is `openai-codex` from the Arch repos on x86. Arch Linux ARM has no such package, so the arm64 image installs it from npm at build time. `cy` is Codex with approvals and sandbox off, meant for VMs.
- **Package count.** The explicit list has about 60 packages. With dependencies it resolves to about 550. Chromium, mpv (ffmpeg), Hyprland and Docker bring most of them. The target of 250 cannot be met without dropping one of the four tool groups.
- **The installer needs the network.** `bambo-install` uses `pacstrap`, the standard Arch path, so the installed system is a clean, current Arch install. An offline installer that copies the live image would be faster but leaves live-session leftovers to clean up.
- **Single source for dotfiles.** `config/` is copied into `/etc/skel` at build time. The live user's home is created from `/etc/skel` at boot, and the installer copies the same `/etc/skel` to the target. There is one copy of every config file in the repo.
- **Window title bars with coloured dots, and a floating activity card,** from the early mockup are not in v0.1. Hyprland has no built-in title bars (that needs a compiled plugin), and the card needs a widget engine. Both would add packages. CPU and RAM are in the top bar.

- **The ISO limit is 3 GB, not the 2.5 GB of the PRD.** The PRD set 2.5 GB before Codex, a full Neovim setup and the helper tools (lazygit, lazydocker, GitHub CLI, yazi, zathura and others) were in scope. With them the ISO is about 2.52 GB. CI fails above 3072 MB.
- **Auto-login stays on after install.** The PRD says "first boot only". With no display manager and no disk encryption, a login prompt adds little, so it is permanent and one `rm` turns it off (see quickstart).
- **Typed answers in the installer use plain shell prompts**, not `gum input`. Under a scripted terminal, gum 2.0 returned empty text for typed input. The disk menu and yes/no prompts still use gum.
- **Fonts.** A fontconfig file makes Inter the default sans font and JetBrains Mono the default monospace font for every app.
- **`docs/PRD.md` is a cleaned-up copy** of the original PRD, not a byte-for-byte one.

- **Scale guard.** Monitor scale is `auto`, which is right for HiDPI laptops. QEMU on macOS reports a tiny physical display, and `auto` then doubled a 720x400 mode into an unusable desktop (found on the first local run). The start hook now falls back to scale 1 when the scaled desktop would be narrower than 1100 px.

- **arm64 is a disk image, not an ISO.** archiso targets x86_64 only. `scripts/build-arm64.sh` runs `pacstrap` from Arch Linux ARM into a raw disk inside an arm64 container and ships it as qcow2, already installed. The idea and the container bootstrap come from [omacom/try-omarchy](https://github.com/omacom/try-omarchy) (MIT). Their patched QEMU, GPU acceleration and Mac integrations are not used: `make try` runs stock Homebrew QEMU with software rendering.
- **Neovim is LazyVim with the Tessera colours.** Omarchy ships LazyVim too. `config/nvim` holds a small bootstrap, three language extras (Python, JSON, Markdown) and a pinned `lazy-lock.json`. Plugins come from GitHub on the first start, so the live ISO needs the network once. The arm64 image downloads them at build time. `gcc`, `tree-sitter-cli`, `fd` and `lazygit` are in the package set for it.
- **Everyday helpers are in the set:** `gh`, lazydocker, bat, eza, zoxide, cliphist, yt-dlp, imv (images) and zathura (PDF). imv, zathura, mpv and Chromium are the default apps in `config/mimeapps.list`. Claude Code is in no Arch repository: the arm64 image installs it from npm at build time, and on the x86 ISO `cl` prints the one-line install. Pi (`pi`, npm package `@earendil-works/pi-coding-agent`, about 170 MB) is installed the same way on arm64. The older `@mariozechner/pi-coding-agent` name is deprecated on npm in favour of this one.
- **Clipboard and sound in `make try`.** The clipboard is a small bridge of our own: a virtio port, `bambo-clipboard` in the guest (wl-clipboard) and `scripts/clipboard-host.py` on the Mac (pbcopy, pbpaste). spice-vdagent was the standard choice, but it drives the X11 clipboard and QEMU's Cocoa window. Ours works on any display backend and can be tested headless. Sound is an Intel HDA output codec on CoreAudio, because the Arch Linux ARM kernel has no virtio sound driver.
- **Shared folder: same uid, no extra layer.** `make try` can share a Mac folder over virtio-9p. Stock QEMU does every file operation as the Mac user, and Linux checks permissions against the numeric owner it sees, so a guest user with another uid cannot write. Try Omarchy patches QEMU to remap the owner. BamboOS keeps stock QEMU and instead creates the VM user with the uid of whoever builds the image. A Mac uid is 501, which systemd counts as a system account, so the image asks PAM for a full user session (`class=user`). Without that there is no user service manager: no notifications and no sound. The other option was bindfs, which is in no Arch repository and adds a FUSE layer.
- **The Mac app is a front for the script.** `Try BamboOS.app` is one Swift file. It sets the environment variables that `try-bambo.sh` documents and calls `--info`, `--stop` and `--reset`. The folder rules live in the script, so `make try` and the app behave the same.
- **arm64 differences.** Kernel is `linux-aarch64`, boot is systemd-boot at the removable EFI path, no microcode, firmware packages or GRUB (`arm64/packages.exclude`). rofi is 1.7.5 through XWayland there.

## Before going public

- Done: release ISOs no longer contain `bambo-smoke`, the root service CI uses to report from inside the VM and to run an unattended install. `make iso` leaves it out. Only `make iso-test` (`BAMBO_SMOKE=1`) includes it, and CI tests that second image. The two images differ by that service only.
- CI covers BIOS boot only. Test UEFI boot and a real laptop first.

## Risks

- Arch is rolling. A Hyprland update can change config syntax, as the move to Lua did. The CI build runs against current Arch on every push, so breakage shows up there first. A weekly scheduled run would catch it without a push.
