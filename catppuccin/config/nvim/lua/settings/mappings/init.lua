--[[
██╗░░██╗███████╗██╗░░░██╗██████╗░██╗███╗░░██╗██████╗░██╗███╗░░██╗░██████╗░░██████╗
██║░██╔╝██╔════╝╚██╗░██╔╝██╔══██╗██║████╗░██║██╔══██╗██║████╗░██║██╔════╝░██╔════╝
█████═╝░█████╗░░░╚████╔╝░██████╦╝██║██╔██╗██║██║░░██║██║██╔██╗██║██║░░██╗░╚█████╗░
██╔═██╗░██╔══╝░░░░╚██╔╝░░██╔══██╗██║██║╚████║██║░░██║██║██║╚████║██║░░╚██╗░╚═══██╗
██║░╚██╗███████╗░░░██║░░░██████╦╝██║██║░╚███║██████╔╝██║██║░╚███║╚██████╔╝██████╔╝
╚═╝░░╚═╝╚══════╝░░░╚═╝░░░╚═════╝░╚═╝╚═╝░░╚══╝╚═════╝░╚═╝╚═╝░░╚══╝░╚═════╝░╚═════╝░
]] --

local map = vim.api.nvim_set_keymap
local keyset = vim.keymap.set

local options = { noremap = true, silent = true }

-- Leader key
vim.g.mapleader = "\\"

-- Better window movement
map('n', '<C-h>', '<C-w>h', options)
map('n', '<C-j>', '<C-w>j', options)
map('n', '<C-k>', '<C-w>k', options)
map('n', '<C-l>', '<C-w>l', options)

-- Resize with arrows
-- map('n', '<Up>', ':resize -2<CR>', options)
-- map('n', '<Down>', ':resize +2<CR>', options)
-- map('n', '<Left>', ':vertical resize -2<CR>', options)
-- map('n', '<Right>', ':vertical resize +2<CR>', options)

-- Shift + tab switch buffers
map('n', '<S-Tab>', ':bnext<CR>', options)

-- Copy to system clipboard
map('v', '<C-c>', '"+y', options)

-- Nerd Tree toggle
-- keyset('n', '<leader>e', ':NERDTreeToggle<CR>', options)

-- Nvim tree toggle
keyset('n', '<leader>e', ':NvimTreeToggle<CR>', options)

-- Telescope keybindings
local builtin = require('telescope.builtin')
keyset('n', '<leader>ff', builtin.find_files, {})
keyset('n', '<leader>fg', builtin.live_grep, {})
keyset('n', '<leader>fb', builtin.buffers, {})
keyset('n', '<leader>fh', builtin.help_tags, {})
keyset('n', '<leader>tm', builtin.colorscheme, {})

-- Telescope git
keyset('n', '<leader>gs', builtin.git_status, {})
keyset('n', '<leader>gc', builtin.git_commits, {})
keyset('n', '<leader>gb', builtin.git_branches, {})

-- Telescope treesitter
keyset('n', '<leader>tt', builtin.treesitter, {})

-- Vimtex
keyset("n", "<leader>q", ":!zathura <C-r>=expand('%:r')<cr>.pdf &<cr>")
keyset("n", "<leader>l", ":VimtexCompile<cr>")
keyset("n", "<leader>ce", ":Copilot enable<cr>")
keyset("n", "<leader>cd", ":Copilot disable<cr>")

-- Markdown preview 
keyset("n", "<leader>mp", ":MarkdownPreview<cr>")
keyset("n", "<leader>ms", ":MarkdownPreviewStop<cr>")
keyset("n", "<leader>mm", ":MarkdownPreviewToggle<cr>")

-- Live server
keyset("n", "<leader>ls", ":LiveServer <cr>")

-- NvChad terminal keybindings 
local fTerm = function ()
    require("nvterm.terminal").toggle "float"
end

local vTerm = function ()
    require("nvterm.terminal").toggle "vertical"
end

local hTerm = function ()
    require("nvterm.terminal").toggle "horizontal"
end

keyset("n", "<leader>tf", fTerm, {})
keyset("t", "<leader>tf", fTerm, {})
keyset("n", "<leader>tv", vTerm, {})
keyset("t", "<leader>tv", vTerm, {})
keyset("n", "<leader>th", hTerm, {})
keyset("t", "<leader>th", hTerm, {})

-- Which key
local wk = require("which-key")

wk.register({
    ["<leader>"] = {
        name = "Leader",
        e = "Explorer",
        f = "Telescope",
        g = "Git",
        t = "Treesitter, Themes and Terminal",
        q = "Zathura",
        l = "Latex compile",
        c = "Copilot",
    },
    ["<leader>f"] = {
        name = "Telescope",
        f = "Find files",
        g = "Live grep",
        b = "Buffers",
        h = "Help tags",
    },
    ["<leader>g"] = {
        name = "Git",
        s = "Git status",
        c = "Git commits",
        b = "Git branches",
    },
    ["<leader>t"] = {
        name = "Treesitter, Themes and Terminal",
        t = "Treesitter",
        m = "Colorscheme",
        f = "Float terminal",
        v = "Vertical terminal",
        h = "Horizontal terminal",
    },
    ["<leader>c"] = {
        name = "Copilot",
        e = "Enable",
        d = "Disable",
    },
    ["<leader>l"] = {
        name = "Latex",
        q = "Zathura",
        l = "Latex compile",
    },
    ["<leader>q"] = {
        name = "Zathura",
        q = "Zathura",
    },
    ["<leader>mp"] = {
        name = "Markdown preview",
        p = "Markdown preview",
        s = "Markdown preview stop",
        m = "Markdown preview toggle",
    },
    ["<leader>ls"] = {
        name = "Live server",
        s = "Live server",
    },
})
