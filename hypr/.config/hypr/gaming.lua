-- =============================================================
--  gaming.lua — Hyprland tweaks for games
--  Loaded from hyprland.lua with:  require("gaming")
-- =============================================================

---------------------------------------------------------------
-- 1. RENDER: fewer layers between the game and the screen
---------------------------------------------------------------

-- direct scanout: when there is a SINGLE fullscreen window, Hyprland stops
-- compositing and sends the game buffer straight to the monitor. Less
-- latency and less GPU use. It used to be 0.
hl.config({ render = { direct_scanout = 1 } })

-- VRR (FreeSync/G-Sync) only when something is fullscreen.
-- 0 = off, 1 = fullscreen only, 2 = always.
-- If you see flicker on the desktop, leave it at 1 (never 2 with NVIDIA).
hl.config({ misc = { vrr = 1 } })

-- Avoids the typical NVIDIA flicker when the framerate changes.
hl.config({ opengl = { nvidia_anti_flicker = true } })

-- HARDWARE CURSOR. Important, do not remove.
-- On automatic (2), NVIDIA ends up with them disabled and Hyprland composites
-- the cursor in software every frame. With a fullscreen game hammering the
-- GPU, that makes the Steam overlay cursor feel sticky.
--   no_hardware_cursors = 0 -> forces the hardware plane
--   use_cpu_buffer      = 1 -> the NVIDIA driver needs CPU-mapped buffers for
--                              that plane; without this the 0 above does
--                              nothing.
-- Check with: hyprctl -j monitors | grep hardwareCursorsInUse  (must be true)
hl.config({ cursor = { no_hardware_cursors = 0, use_cpu_buffer = 1 } })

-- Tearing: disabled. With 165 Hz + VRR it is not needed and it causes
-- artefacts. If you play competitively and want the lowest possible latency,
-- set it to true and uncomment the "immediate" rule below.
hl.config({ general = { allow_tearing = false } })


---------------------------------------------------------------
-- 2. ENVIRONMENT VARIABLES
---------------------------------------------------------------

-- NVIDIA shader cache, persistent across sessions.
hl.env("__GL_SHADER_DISK_CACHE", "1")
hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")

-- Direct backend for NVIDIA video acceleration (VA-API).
hl.env("NVD_BACKEND", "direct")

-- Do NOT set SDL_VIDEODRIVER=wayland or QT_QPA_PLATFORM=wayland here.
-- They break plenty of games using older SDL2; letting them fall back to
-- XWayland is the right thing, and gamescope handles the rest.


---------------------------------------------------------------
-- 3. WINDOW RULES: the fullscreen that never fails
---------------------------------------------------------------

-- Classes we consider "a game":
--   gamescope          -> anything launched with the `gs` script
--   steam_app_<id>     -> Steam games under XWayland without gamescope
--   .exe               -> some Proton games identify themselves this way
local GAMES = "^(gamescope|steam_app_.*|.*\\.exe|hl2_linux|cs2)$"

hl.window_rule({
    name  = "games-fullscreen",
    match = { class = GAMES },

    -- ALWAYS on the landscape 1440p monitor, never on the portrait one.
    -- MONITOR_MAIN is defined by hyprland.lua before require("gaming"); it is
    -- an EDID description, not a connector name, because connector names
    -- change across kernels.
    monitor      = MONITOR_MAIN,
    fullscreen   = true,         -- and always fullscreen
    border_size  = 0,
    rounding     = 0,
    no_anim      = true,         -- animations get in the way entering/leaving
    idle_inhibit = "fullscreen", -- keep the screensaver away while playing
    content      = "game",       -- hint to the compositor: prioritise latency
})

-- For competitive play with tearing (requires allow_tearing = true above):
-- hl.window_rule({
--     name  = "games-tearing",
--     match = { class = "^(cs2|gamescope)$" },
--     immediate = true,
-- })


---------------------------------------------------------------
-- 4. THE STEAM CLIENT: taming its quirks
---------------------------------------------------------------

-- Steam context menus have an empty title and close themselves when they
-- lose focus. These two rules are the standard fix.
hl.window_rule({
    name  = "steam-context-menus",
    match = { class = "^steam$", title = "^$" },
    stay_focused = true,
    min_size     = "1 1",
})

-- Secondary Steam windows: float them instead of splitting the layout.
hl.window_rule({
    name  = "steam-loose-windows",
    match = { class = "^steam$",
              title = "^(Friends List|Lista de amigos|Steam Settings|Configuraci.n|Special Offers|Steam - News|Steam Guard.*|Iniciar sesi.n en Steam|Sign in to Steam)$" },
    float = true,
})

-- Big Picture: fullscreen on the main monitor.
hl.window_rule({
    name  = "steam-big-picture",
    match = { class = "^steam$", title = "^Steam Big Picture Mode$" },
    monitor    = MONITOR_MAIN,
    fullscreen = true,
})


---------------------------------------------------------------
-- 5. NO GAPS WHEN THERE IS ONLY ONE WINDOW
---------------------------------------------------------------
-- So a maximised windowed game does not leave odd borders either.

hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({
    name  = "no-gaps-fullscreen",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})


---------------------------------------------------------------
-- 6. CAPTURE CARD (PS5 / Switch 2 through the NZXT Signal HD60)
---------------------------------------------------------------
-- The `capture-card` script launches mpv with
-- --wayland-app-id=capture-card, which is how we can target a rule at it
-- without affecting the rest of mpv.
-- Floating and at exactly 1920x1080, the native resolution of the capture
-- card: no rescaling. mpv's f key toggles fullscreen and comes back to this
-- size.

hl.window_rule({
    name  = "capture-card",
    match = { class = "^capture-card$" },

    float        = true,          -- never tiled
    size         = "1920 1080",   -- 1:1 with the signal, no rescaling
    center       = true,
    monitor      = MONITOR_MAIN,
    border_size  = 0,             -- video only, like PotPlayer
    rounding     = 0,
    no_anim      = true,
    idle_inhibit = "always",      -- a gamepad does not move the mouse: without
                                  -- this the screensaver would kick in mid-game
    content      = "game",
})


---------------------------------------------------------------
-- 7. RETROARCH
---------------------------------------------------------------
-- RetroArch runs as a native Wayland client and identifies itself with the
-- app_id "com.libretro.RetroArch" (not "retroarch": that is the X11 WM_CLASS,
-- which we never see because there is no XWayland here).
--
-- Its menu is designed around a 16:9 canvas and tiling squashes it into
-- whatever slot the layout has free, so it always floats. Fullscreen still
-- works on top of this: floating only decides how the window sits when it is
-- NOT fullscreen, which is exactly the menu and the windowed play mode.

hl.window_rule({
    name  = "retroarch-float",
    match = { class = "^com\\.libretro\\.RetroArch$" },

    float   = true,
    center  = true,
    monitor = MONITOR_MAIN,
})


---------------------------------------------------------------
-- 8. SHORTCUTS
---------------------------------------------------------------

-- THE DESCRIPTIONS ARE NOT DECORATION. The cheatsheet on SUPER + / lists a
-- bind only if it carries one, and these two are the only window actions that
-- live in this file instead of hyprland.lua's KEYBINDINGS section -- which is
-- how they spent so long absent from a page that claims to show everything.
-- The wording is the niri config's hotkey-overlay-title for the same chord,
-- word for word: the two cheatsheets have to read the same, or "every keybind
-- is the same in both" is a claim nobody can check from the screen.

-- SUPER + F  : force fullscreen on the active window.
--              Your safety net if a game opens in a tiny window.
hl.bind("SUPER + F", hl.dsp.window.fullscreen(), { description = "Windows: fullscreen" })

-- SUPER + SHIFT + F : "fake" fullscreen (the game thinks it is still
--              windowed but takes the whole screen). Fixes games that
--              minimise on alt-tab.
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0 }),
        { description = "Windows: fake fullscreen (for games that minimise)" })
