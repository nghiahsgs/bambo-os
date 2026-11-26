# Tessera design tokens

One palette for every surface: Hyprland borders, waybar, launcher, terminal, lock screen, wallpaper.

- Background: `#101012` (charcoal)
- Surface: `#161618`
- Border (hairline): `rgba(255,255,255,0.08)`, 1px. Hex with alpha: `#ffffff14`
- Text primary: `#f4f4f5`
- Text muted: `#8e8e96`
- Accent blue (info, focus): `#5b8def`
- Accent orange (warning): `#ff8a4c`
- Accent green (success): `#3ecf8e`
- Red (recording, errors): `#f0616d`
- UI font: Inter
- Mono font: JetBrainsMono Nerd Font, ligatures on
- Radius: 12px
- Focused window border: accent blue, 1px

Where each token is applied:

- `config/hypr/tessera.lua`: borders, radius
- `config/waybar/style.css`: top bar and dock
- `config/rofi/config.rasi`: launcher, power menu, cheat sheet
- `config/kitty/kitty.conf`: terminal colours
- `config/mako/config`: notifications
- `config/hypr/hyprlock.conf`: lock screen
- `themes/tessera/make-wallpaper.py`: wallpaper
