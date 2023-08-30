-- Autostart apps
local awful = require("awful")

-- Load autostart apps
awful.spawn.with_shell("picom")
awful.spawn.with_shell("nitrogen --restore")
