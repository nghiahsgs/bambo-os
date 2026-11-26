-- BamboOS keybindings. Super is the centre of everything.
-- Keep config/bambo/keys.txt in sync: that file feeds the Super + / cheat sheet.
local mod      = "SUPER"
local terminal = "kitty"
local browser  = "chromium"

-- Apps
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + space",  hl.dsp.exec_cmd("rofi -show drun"))

-- Windows
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Focus and swap, vim style
local dirs = { H = "left", J = "down", K = "up", L = "right" }
for key, dir in pairs(dirs) do
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end

-- Workspaces 1..9
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Capture
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("bambo-shot"))
hl.bind("Print",               hl.dsp.exec_cmd("bambo-shot full"))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("bambo-record toggle"))

-- Session. Super + L is focus-right, so lock lives on Super + Escape.
hl.bind(mod .. " + Escape",    hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("bambo-power"))
hl.bind(mod .. " + slash",     hl.dsp.exec_cmd("bambo-keys"))

-- Mouse is optional, but it works
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop keys
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                 { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                             { locked = true })
