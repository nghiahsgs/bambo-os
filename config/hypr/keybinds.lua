-- BamboOS keybindings. Super is the centre of everything.
-- The chords follow Omarchy wherever BamboOS has the same feature, so there is
-- nothing to relearn when moving between the two.
-- Keep config/bambo/keys.txt in sync: that file feeds the Super + K cheat sheet.
local mod      = "SUPER"
local terminal = "kitty"
local browser  = "chromium"

local function run(cmd) return hl.dsp.exec_cmd(cmd) end
local function tui(cmd) return hl.dsp.exec_cmd(terminal .. " -e " .. cmd) end

-- Apps
hl.bind(mod .. " + Return",         run(terminal))
hl.bind(mod .. " + ALT + Return",   tui("tmux new-session -A -s main"))
hl.bind(mod .. " + SHIFT + Return", run(browser))
hl.bind(mod .. " + SHIFT + B",      run(browser))
hl.bind(mod .. " + B",              run(browser))
hl.bind(mod .. " + SHIFT + F",      tui("yazi"))
hl.bind(mod .. " + SHIFT + N",      tui("nvim"))
hl.bind(mod .. " + SHIFT + T",      tui("btop"))
hl.bind(mod .. " + SHIFT + A",      tui("bambo-codex"))
hl.bind(mod .. " + space",          run("rofi -show drun"))
-- macOS keeps Cmd + Space when BamboOS runs in a VM, so the launcher has a second chord.
hl.bind(mod .. " + ALT + space",    run("rofi -show drun"))

-- Windows
hl.bind(mod .. " + W",       hl.dsp.window.close())
hl.bind(mod .. " + Q",       hl.dsp.window.close())
hl.bind(mod .. " + F",       hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + T",       hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J",       hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + P",       hl.dsp.window.pseudo())

-- Focus with the arrows, swap with Shift
local dirs = { Left = "left", Down = "down", Up = "up", Right = "right" }
for key, dir in pairs(dirs) do
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }))
end
hl.bind("ALT + Tab",         hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))

-- Resize: Super + minus / equal for width, with Shift for height
hl.bind(mod .. " + minus",         hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + equal",         hl.dsp.window.resize({ x = 100, y = 0, relative = true }),  { repeating = true })
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }),  { repeating = true })

-- Workspaces 1..10 (0 is the tenth)
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + Tab",         hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + CTRL + Tab",  hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + mouse_down",  hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + mouse_up",    hl.dsp.focus({ workspace = "m-1" }))

-- Scratchpad: a workspace that slides over the current one
hl.bind(mod .. " + S",       hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Clipboard: Super + C / V / X / A work everywhere, the terminal included.
-- The key goes down and up in two steps because a single send can leave it repeating.
local function send(mods, key)
    return function()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
        hl.timer(function()
            hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
        end, { timeout = 50, type = "oneshot" })
    end
end
local function in_terminal()
    local window = hl.get_active_window()
    return window ~= nil and window.class == terminal
end
local function clipboard(key)
    return function()
        send(in_terminal() and "CTRL SHIFT" or "CTRL", key)()
    end
end
hl.bind(mod .. " + C", clipboard("C"))
hl.bind(mod .. " + V", clipboard("V"))
hl.bind(mod .. " + X", send("CTRL", "X"))
hl.bind(mod .. " + A", send("CTRL", "A"))

-- Capture
hl.bind(mod .. " + SHIFT + S", run("bambo-shot"))
hl.bind("Print",               run("bambo-shot full"))
hl.bind(mod .. " + SHIFT + R", run("bambo-record toggle"))

-- Session
hl.bind(mod .. " + Escape",   run("bambo-power"))
hl.bind(mod .. " + CTRL + L", run("hyprlock"))
hl.bind(mod .. " + K",        run("bambo-keys"))
hl.bind(mod .. " + slash",    run("bambo-keys"))

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
