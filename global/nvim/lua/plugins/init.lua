--[[
██████╗░██╗░░░░░██╗░░░██╗░██████╗░██╗███╗░░██╗░██████╗
██╔══██╗██║░░░░░██║░░░██║██╔════╝░██║████╗░██║██╔════╝
██████╔╝██║░░░░░██║░░░██║██║░░██╗░██║██╔██╗██║╚█████╗░
██╔═══╝░██║░░░░░██║░░░██║██║░░╚██╗██║██║╚████║░╚═══██╗
██║░░░░░███████╗╚██████╔╝╚██████╔╝██║██║░╚███║██████╔╝
╚═╝░░░░░╚══════╝░╚═════╝░░╚═════╝░╚═╝╚═╝░░╚══╝╚═════╝░
--]]

vim.cmd "packadd packer.nvim"

local packer = require("packer")

packer.init({
  git = {
    clone_timeout = 600, -- Timeout, in seconds, for git clones
  },
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "single" })
    end,
  },
})

require("packer").startup(function(use)
    -- Packer can manage itself
    use "wbthomason/packer.nvim"

    -- Treesitter
    use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }

    -- Nvterm
    use "NvChad/nvterm"

    -- alpha
    -- use {
    --     'goolord/alpha-nvim',
    --     requires = { 'kyazdani42/nvim-web-devicons' },
    --     config = function ()
    --         require'alpha'.setup(require'alpha.themes.startify'.config)
    --     end
    -- }

    -- Themes
    use "projekt0n/github-nvim-theme"
    use 'doki-theme/doki-theme-vim'
    use 'folke/tokyonight.nvim'
    use 'sainnhe/gruvbox-material'
    use 'cocopon/iceberg.vim'
    use 'morhetz/gruvbox'
    use 'sainnhe/sonokai'
    use 'sainnhe/everforest'
    use 'sainnhe/edge'
    use { "catppuccin/nvim", as = "catppuccin" }

    -- Bufferline
    use {'akinsho/bufferline.nvim', tag = "v3.*", requires = 'nvim-tree/nvim-web-devicons'}

    -- LSP
    use 'neovim/nvim-lspconfig'

    -- Which key
    use 'folke/which-key.nvim'

    -- Rust analyzer
    use 'simrat39/rust-tools.nvim'
   -- use 'rust-lang/rust-analyzer'

    -- Web devicons
    use 'kyazdani42/nvim-web-devicons'

    -- Copilot
    use 'github/copilot.vim'
    
    -- Live server
    use({
        "aurum77/live-server.nvim",
        run = function()
            require"live_server.util".install()
        end,
        cmd = { "LiveServer", "LiveServerStart", "LiveServerStop" },
    })

    -- Git signs
    use 'lewis6991/gitsigns.nvim'

    -- Telescope
    use 'nvim-lua/popup.nvim'
    use 'nvim-lua/plenary.nvim'
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.0',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    -- Latex
    use 'lervag/vimtex'

    -- snippets
    use 'norcalli/snippets.nvim'
    use 'SirVer/ultisnips'
    use 'honza/vim-snippets'

    -- Lua
    use {
        "folke/todo-comments.nvim",
        requires = "nvim-lua/plenary.nvim"
    }

    -- TypeScript lsp
    use 'albingroen/nvim-lsp-typescript-config'

    -- Color highlight
    use 'Pocco81/HighStr.nvim'

    -- Hex colors
    use 'chrisbra/Colorizer'

    -- vim commentary
    use 'tpope/vim-commentary'

    -- Java lsp
    use 'mfussenegger/nvim-jdtls'

    -- Tree
    use "preservim/nerdtree"

    -- install without yarn or npm
    use({
        "iamcco/markdown-preview.nvim",
        run = function() vim.fn["mkdp#util#install"]() end,
    })

    -- nvim tree
    use {
      'nvim-tree/nvim-tree.lua',
      requires = {
        'nvim-tree/nvim-web-devicons', -- optional, for file icons
      },
      tag = 'nightly' -- optional, updated every week. (see issue #1193)
    }

    -- Discord
    use 'andweeb/presence.nvim'

    -- PlantUML syntax
    use 'aklt/plantuml-syntax'

    use 'hrsh7th/cmp-nvim-lsp'
    use 'hrsh7th/cmp-buffer'
    use 'hrsh7th/cmp-path'
    use 'hrsh7th/cmp-cmdline'
    use 'hrsh7th/nvim-cmp'
    use 'L3MON4D3/LuaSnip'
    use 'saadparwaiz1/cmp_luasnip'
    use {
        'nvim-lualine/lualine.nvim',
        requires = { 'kyazdani42/nvim-web-devicons', opt = true }
    }
end)
