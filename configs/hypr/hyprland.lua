-- hyprland.lua 2026
-- saltyfunnel/hpr

--------------------------------------------------------------------------------
-- monitor
--------------------------------------------------------------------------------

-- auto: preferred resolution/refresh on whatever is connected
hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = 1,
})

--------------------------------------------------------------------------------
-- gpu environment
--------------------------------------------------------------------------------

local gpu_env = dofile(os.getenv("HOME") .. "/.config/hypr/gpu-env.lua")
hl.config({ env = gpu_env })

--------------------------------------------------------------------------------
-- environment
--------------------------------------------------------------------------------

hl.config({
  env = {
    XCURSOR_THEME = "Nordzy-cursors",
    XCURSOR_SIZE  = "24",
  }
})
--------------------------------------------------------------------------------
-- autostart
--------------------------------------------------------------------------------

hl.exec_once("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
hl.exec_once("/usr/lib/polkit-kde-authentication-agent-1")
hl.exec_once("awww-daemon --format xrgb")
hl.exec_once("waybar")
hl.exec_once("mako")
hl.exec_once("udiskie")

--------------------------------------------------------------------------------
-- input
--------------------------------------------------------------------------------

hl.config({
  input = {
    kb_layout    = "gb",
    follow_mouse = 1,
    sensitivity  = 0,
    touchpad = {
      natural_scroll = false,
    },
  }
})
--------------------------------------------------------------------------------
-- look & feel
--------------------------------------------------------------------------------

hl.config({
  general = {
    gaps_in          = 2,
    gaps_out         = 2,
    border_size      = 3,
    resize_on_border = true,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding         = 10,
    active_opacity   = 1.0,
    inactive_opacity = 1.0,
  },

  misc = {
    force_default_wallpaper  = 0,
    disable_hyprland_logo    = true,
    disable_splash_rendering = true,
    vrr                      = 0,
  },

  cursor = {
    no_hardware_cursors = false,
  },
})

--------------------------------------------------------------------------------
-- animations
--------------------------------------------------------------------------------

hl.config({
  bezier = {
    wind  = { 0.05, 0.9,  0.1, 1.05 },
    winIn = { 0.1,  1.1,  0.1, 1.1  },
    winOut= { 0.3,  -0.3, 0,   1    },
    liner = { 1,    1,    1,   1    },
  },

  animation = {
    { name = "windows",     enable = true, speed = 6,  bezier = "wind",   style = "slide" },
    { name = "windowsIn",   enable = true, speed = 6,  bezier = "winIn",  style = "slide" },
    { name = "windowsOut",  enable = true, speed = 5,  bezier = "winOut", style = "slide" },
    { name = "windowsMove", enable = true, speed = 5,  bezier = "wind",   style = "slide" },
    { name = "border",      enable = true, speed = 1,  bezier = "liner"                   },
    { name = "borderangle", enable = true, speed = 30, bezier = "liner",  style = "loop"  },
    { name = "fade",        enable = true, speed = 10, bezier = "default"                 },
    { name = "workspaces",  enable = true, speed = 5,  bezier = "wind"                    },
  },
})
--------------------------------------------------------------------------------
-- window rules
--------------------------------------------------------------------------------

-- floating
hl.window_rule({ match = { class = "pavucontrol"    }, float  = true })
hl.window_rule({ match = { class = "blueman-manager"}, float  = true })
hl.window_rule({ match = { title = "WallpaperPicker"}, float  = true })
hl.window_rule({ match = { title = "WallpaperPicker"}, center = true })

-- opacity
hl.window_rule({ match = { class = "firefox"       }, opacity = "1.0"      })
hl.window_rule({ match = { class = "dev.zed.Zed"   }, opacity = "0.90"     })
hl.window_rule({ match = { class = "spotify"       }, opacity = "0.80"     })
hl.window_rule({ match = { class = "kitty"         }, opacity = "0.80"     })
hl.window_rule({ match = { class = "thunar"        }, opacity = "0.80 0.80"})
--------------------------------------------------------------------------------
-- keybinds
--------------------------------------------------------------------------------

local mod  = "SUPER"
local term = "kitty"
local ed   = "zeditor"
local br   = "firefox"
local fm   = "thunar"

-- core
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(term))
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("hyprctl dispatch exit"))
hl.bind(mod .. " + Q",      hl.dsp.window.close())
hl.bind(mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))

-- apps
hl.bind(mod .. " + F", hl.dsp.exec_cmd(fm))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("python3 ~/.config/scripts/wall.py"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("python3 ~/.config/scripts/app.py"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd(ed))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(br))
hl.bind(mod .. " + I", hl.dsp.exec_cmd(term .. " -e btop"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("spotify"))

-- trash
hl.bind(mod .. " + ALT + E", hl.dsp.exec_cmd(
  "sh -c \"trash-empty -f; notify-send -i user-trash-full 'Trash Service' 'Wastebasket has been cleared across all drives.'\""
))

-- media
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeat_ = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeat_ = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"))

-- focus
hl.bind(mod .. " + H", hl.dsp.window.focus("l"))
hl.bind(mod .. " + L", hl.dsp.window.focus("r"))
hl.bind(mod .. " + K", hl.dsp.window.focus("u"))
hl.bind(mod .. " + J", hl.dsp.window.focus("d"))

-- workspaces
for i = 1, 5 do
  hl.bind(mod .. " + " .. i,             hl.dsp.workspace(i))
  hl.bind(mod .. " + SHIFT + " .. i,     hl.dsp.window.move_to_workspace(i))
end

-- scroll workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.workspace("e+1"))
hl.bind(mod .. " + mouse_up",   hl.dsp.workspace("e-1"))

-- move/resize with mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
--------------------------------------------------------------------------------
-- pywal colors
--------------------------------------------------------------------------------

local function read_color(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local c = f:read("*l")
  f:close()
  return c and c:gsub("%s+", "") or nil
end

local wal = os.getenv("HOME") .. "/.cache/wal/colors"
local colors = {}
local f = io.open(wal, "r")
if f then
  for line in f:lines() do
    colors[#colors + 1] = line:gsub("%s+", "")
  end
  f:close()
end

local color2 = colors[3]  -- wal is 0-indexed, lua is 1-indexed so color2 = index 3
local color4 = colors[5]
local color8 = colors[9]

if color2 and color4 and color8 then
  hl.config({
    general = {
      col_active_border   = color4 .. " " .. color2 .. " 45deg",
      col_inactive_border = color8,
    }
  })
end
