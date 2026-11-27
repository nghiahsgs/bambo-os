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

- **Auto-login stays on after install.** The PRD says "first boot only". With no display manager and no disk encryption, a login prompt adds little, so it is permanent and one `rm` turns it off (see quickstart).
- **Typed answers in the installer use plain shell prompts**, not `gum input`. Under a scripted terminal, gum 2.0 returned empty text for typed input. The disk menu and yes/no prompts still use gum.
- **Fonts.** A fontconfig file makes Inter the default sans font and JetBrains Mono the default monospace font for every app.
- **`docs/PRD.md` is a cleaned-up copy** of the original PRD, not a byte-for-byte one.

- **Scale guard.** Monitor scale is `auto`, which is right for HiDPI laptops. QEMU on macOS reports a tiny physical display, and `auto` then doubled a 720x400 mode into an unusable desktop (found on the first local run). The start hook now falls back to scale 1 when the scaled desktop would be narrower than 1100 px.

- **arm64 is a disk image, not an ISO.** archiso targets x86_64 only. `scripts/build-arm64.sh` runs `pacstrap` from Arch Linux ARM into a raw disk inside an arm64 container and ships it as qcow2, already installed. The idea and the container bootstrap come from [omacom/try-omarchy](https://github.com/omacom/try-omarchy) (MIT). Their patched QEMU, GPU acceleration and Mac integrations are not used: `make try` runs stock Homebrew QEMU with software rendering.
- **arm64 differences.** Kernel is `linux-aarch64`, boot is systemd-boot at the removable EFI path, no microcode, firmware packages or GRUB (`arm64/packages.exclude`). rofi is 1.7.5 through XWayland there.

## Before going public

- Done: release ISOs no longer contain `bambo-smoke`, the root service CI uses to report from inside the VM and to run an unattended install. `make iso` leaves it out. Only `make iso-test` (`BAMBO_SMOKE=1`) includes it, and CI tests that second image. The two images differ by that service only.
- CI covers BIOS boot only. Test UEFI boot and a real laptop first.

## Risks

- Arch is rolling. A Hyprland update can change config syntax, as the move to Lua did. The CI build runs against current Arch on every push, so breakage shows up there first. A weekly scheduled run would catch it without a push.
