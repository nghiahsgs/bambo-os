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
- **`Super + L` was assigned twice** (focus right, and lock). Focus keeps `H/J/K/L`. Lock moved to `Super + Escape`.
- **Package count.** The explicit list has about 60 packages. With dependencies it resolves to about 550. Chromium, mpv (ffmpeg), Hyprland and Docker bring most of them. The target of 250 cannot be met without dropping one of the four tool groups.
- **The installer needs the network.** `bambo-install` uses `pacstrap`, the standard Arch path, so the installed system is a clean, current Arch install. An offline installer that copies the live image would be faster but leaves live-session leftovers to clean up.
- **Single source for dotfiles.** `config/` is copied into `/etc/skel` at build time. The live user's home is created from `/etc/skel` at boot, and the installer copies the same `/etc/skel` to the target. There is one copy of every config file in the repo.
- **Window title bars with coloured dots, and a floating activity card,** from the early mockup are not in v0.1. Hyprland has no built-in title bars (that needs a compiled plugin), and the card needs a widget engine. Both would add packages. CPU and RAM are in the top bar.

## Risks

- Arch is rolling. A Hyprland update can change config syntax, as the move to Lua did. The CI build runs against current Arch on every push, so breakage shows up there first. A weekly scheduled run would catch it without a push.
