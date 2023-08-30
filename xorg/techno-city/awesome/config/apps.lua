local menubar = require("menubar")

apps = {

  -- Your default terminal
  terminal        = "alacritty",

  -- Your default text editor
  editor          = os.getenv("EDITOR") or "nvim",

  -- Your default file explorer
  explorer        = "nemo",

}

apps.editor_cmd   = apps.terminal .. " -e " .. apps.editor
apps.explorer_cmd = apps.terminal .. " -e " .. apps.explorer
menubar.utils.terminal = apps.terminal -- Set the terminal for applications that require it

return apps
