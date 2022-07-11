local wezterm = require 'wezterm';

-- Write inside of this return all the configs of the terminal
return {

  leader = {key="a", mods="CTRL"},
  
  -- font of the terminal
  font = wezterm.font("JetBrains Mono"),
  
  -- Font size of the terminal
  font_size = 10,

  -- disable warning
  warn_about_missing_glyphs = false,

  -- Color theme of the terminal
  color_scheme = "wezterm_tokyonight_night",

  -- Opactity
  window_background_opacity = 0.90,

  -- Tab bar position
  tab_bar_at_bottom = true,

  -- Adjust the font size
  adjust_window_size_when_changing_font_size = false,

  -- Hide tab bar
  enable_tab_bar = false,
  -- hide_tab_bar_if_only_one_tab = true,
 
  keys = {
    
  -- Send "CTRL-A" to the terminal when pressing CTRL-A, CTRL-A
  {key="a", mods="LEADER", action=wezterm.action{SendString='cd ~/Documents/TEC/"Computer Engineering"/2022/'}},

  {key="s", mods="LEADER", action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
  
  },

  -- colors = {
  -- -- The default text colors
  -- foreground = "#c0caf5",
  -- -- The default background color
  -- background = "#1a1b26",

  -- -- Overrides the cell background color when the current cell is occupied by theme
  -- -- cursor and the cursor style is set to Block
  -- cursor_bg = "#c0caf5",
  -- -- Overrides the text color when the current cell is occupied by the cursor
  -- cursor_fg = "#1a1b26",
  -- -- Specifies the border color of the cursor when the cursor style is set to Block,
  -- -- or the color of the vertical or horizontal bar when the cursor style is set to
  -- -- Bar or Underline.
  -- cursor_border = "#c0caf5",

  -- -- the foreground color of selected text
  -- selection_fg = "#33467C",
  -- -- the background color of selected text
  -- selection_bg = "#c0caf5",

  -- -- The color of the scrollbar "thumb"; the portion that represents the current viewport
  -- scrollbar_thumb = "#33467C",
  -- 
  -- -- The color of the split lines between panes
  -- split = "#c0caf5",

  -- ansi = {"#15161E", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6"},
  -- brights = {"#414868", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#c0caf5"},

  -- -- Arbitrary colors of the palette in the range from 16 to 255
  -- indexed = {[136] = "#af8700"},

  -- compose_cursor = "orange",
  -- }
}

