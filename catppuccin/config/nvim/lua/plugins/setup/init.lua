--[[
██████╗░██╗░░░░░██╗░░░██╗░██████╗░██╗███╗░░██╗░██████╗  ░██████╗███████╗████████╗██╗░░░██╗██████╗░
██╔══██╗██║░░░░░██║░░░██║██╔════╝░██║████╗░██║██╔════╝  ██╔════╝██╔════╝╚══██╔══╝██║░░░██║██╔══██╗
██████╔╝██║░░░░░██║░░░██║██║░░██╗░██║██╔██╗██║╚█████╗░  ╚█████╗░█████╗░░░░░██║░░░██║░░░██║██████╔╝
██╔═══╝░██║░░░░░██║░░░██║██║░░╚██╗██║██║╚████║░╚═══██╗  ░╚═══██╗██╔══╝░░░░░██║░░░██║░░░██║██╔═══╝░
██║░░░░░███████╗╚██████╔╝╚██████╔╝██║██║░╚███║██████╔╝  ██████╔╝███████╗░░░██║░░░╚██████╔╝██║░░░░░
╚═╝░░░░░╚══════╝░╚═════╝░░╚═════╝░╚═╝╚═╝░░╚══╝╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░░╚═════╝░╚═╝░░░░░
]]--

-- Treesitter
require("plugins.setup.treesitter")

-- Todo comments
require("plugins.setup.todo-comments")

-- Lualine
require("plugins.setup.lualine")

-- Vimtex 
require("plugins.setup.vimtex")

-- Copilot
require("plugins.setup.copilot")

-- cmp
require("plugins.setup.cmp")

-- nvim tree
require("plugins.setup.nvim-tree")

-- which key
require("plugins.setup.which-key")

-- Catppuccin 
require("plugins.setup.catppuccin")

-- Gitsigns 
require("plugins.setup.gitsigns")

-- NvChad term
require("plugins.setup.nvchad-term")

-- Markdown preview
require("plugins.setup.markdown-preview")

-- Bufferline
vim.opt.termguicolors = true
require("bufferline").setup{}

-- Live servers
require("plugins.setup.live-server")
