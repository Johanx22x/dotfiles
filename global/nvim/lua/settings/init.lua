--[[
░██████╗███████╗████████╗████████╗██╗███╗░░██╗░██████╗░░██████╗
██╔════╝██╔════╝╚══██╔══╝╚══██╔══╝██║████╗░██║██╔════╝░██╔════╝
╚█████╗░█████╗░░░░░██║░░░░░░██║░░░██║██╔██╗██║██║░░██╗░╚█████╗░
░╚═══██╗██╔══╝░░░░░██║░░░░░░██║░░░██║██║╚████║██║░░╚██╗░╚═══██╗
██████╔╝███████╗░░░██║░░░░░░██║░░░██║██║░╚███║╚██████╔╝██████╔╝
╚═════╝░╚══════╝░░░╚═╝░░░░░░╚═╝░░░╚═╝╚═╝░░╚══╝░╚═════╝░╚═════╝░
]]--

-- Settings
vim.cmd [[
    set nowrap
    set tabstop=4
    set shiftwidth=4
    set expandtab
    syntax on
]]

-- Colorscheme
vim.cmd [[
    colorscheme tokyonight
]]

-- Transparent background
vim.cmd [[
    highlight Normal guibg=NONE ctermbg=NONE
]]

-- transparent background for nvimTree
vim.cmd [[
    highlight nvimTreeNormal guibg=NONE ctermbg=NONE
    highlight NormalNC guibg=NONE ctermbg=NONE
]]

-- Spell check 
vim.cmd [[
    set spell
    set spelllang=en_us
    inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u
]]

-- snippets
vim.g.UltiSnipsExpandTrigger = "<tab>"
vim.g.UltiSnipsJumpForwardTrigger = "<c-b>"
vim.g.UltiSnipsJumpBackwardTrigger = "<c-z>"

-- Numbers column
vim.o.number = true
vim.o.relativenumber = true
