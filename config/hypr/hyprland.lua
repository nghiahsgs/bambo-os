-- BamboOS Hyprland config (Lua, Hyprland >= 0.55).
-- Docs: https://wiki.hypr.land/configuring/
local t = require("tessera")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

---- Environment ----
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

---- Autostart ----
hl.on("hyprland.start", function()
    hl.exec_cmd("swaybg -m fill -c '#101012' -i /usr/share/bambo/tessera/wallpaper.png")
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("xdg-user-dirs-update")
    hl.exec_cmd("notify-send -a BamboOS 'Welcome to BamboOS' 'Super + / shows every shortcut.'")
end)

---- Look and feel ----
hl.config({
    general = {
        gaps_in     = 8,
        gaps_out    = 20,
        border_size = t.border_size,
        col = {
            active_border   = t.blue,
            inactive_border = t.border,
        },
        resize_on_border = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = t.rounding,
        shadow = { enabled = false },
        blur   = { enabled = false },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
})

-- Short, quiet animations.
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},    {1, 1}    } })
hl.animation({ leaf = "global",     enabled = true, speed = 3,   bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",    enabled = true, speed = 2.5, bezier = "easeOutQuint", style = "popin 92%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2,   bezier = "linear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2,   bezier = "easeOutQuint", style = "fade" })

---- Rules ----
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

require("keybinds")
