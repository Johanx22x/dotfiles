vim.cmd "packadd packer.nvim"

vim.g.mapleader = " "
vim.keymap.set('n', '<leader>d', ":NERDTreeToggle<CR>")

require("packer").startup(function(use)
	use "wbthomason/packer.nvim"
	use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
	use "projekt0n/github-nvim-theme"
	use 'doki-theme/doki-theme-vim'
	use 'neovim/nvim-lspconfig'
    
    -- Color highlight
    use 'Pocco81/HighStr.nvim'

    -- Hex colors
    use 'chrisbra/Colorizer'

    -- Tree
    use "preservim/nerdtree"
    
    -- Discord
    use 'andweeb/presence.nvim'

	-- tokyo night theme
	use 'folke/tokyonight.nvim'

	-- gruvbox material theme
	use 'sainnhe/gruvbox-material'

	-- iceberg theme
	use 'cocopon/iceberg.vim'

	-- gruvbox theme
	use 'morhetz/gruvbox'

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

require("nvim-treesitter.configs").setup {
    highlight = {
        enable = true,
    },
}

require("lualine").setup({
    options = {
        theme = 'tokyonight',
        -- theme = 'emilia_dark',
        section_separators = '',
        component_separators = '|',
    }
})

vim.cmd "colorscheme tokyonight"

vim.cmd "set nowrap"

vim.cmd "hi Normal ctermbg=NONE guibg=NONE"

vim.cmd "set tabstop=4"
vim.cmd "set shiftwidth=4"
vim.cmd "set expandtab"

vim.o.number = true
vim.o.relativenumber = true

local servers = {
    "gopls",
    "jedi_language_server",
    -- "sumneko_lua",
    "clangd",
    "rls",
    "hls",
    "tsserver",
}


local function on_attach()
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references)
    vim.keymap.set('n', '<leader>f', vim.lsp.buf.formatting)
end

local high_str = require("high-str")

high_str.setup({
    verbosity = 0,
    saving_path = "/tmp/highstr/",
    highlight_colors = {
        -- color_id = {"bg_hex_code", <"fg_hex_code"/"smart">}
        color_0 = {"#0c0d0e", "smart"},
        color_1 = {"#e5c07b", "smart"},
        color_2 = {"#7FFFD4", "smart"},
        color_3 = {"#8A2BE2", "smart"},
        color_4 = {"#FF4500", "smart"},
        color_5 = {"#008000", "smart"},
        color_6 = {"#0000FF", "smart"},
        color_7 = {"#FFC0CB", "smart"},
        color_8 = {"#FFF9E3", "smart"},
        color_9 = {"#7d5c34", "smart"},
    }
})

local cmp = require('cmp')

cmp.setup({
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
        end,
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    }),
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'luasnip' }, -- For luasnip users.
    }, {
        { name = 'buffer' },
    })
})

cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
        { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
    }, {
        { name = 'buffer' },
    })
})

for _, server in ipairs(servers) do
    require("lspconfig")[server].setup {
        on_attach = on_attach,
        flags = {
            debounce_text_changes = 150,
        },
        settings = {
            Lua = {
                diagnostics = {
                    globals = { 'vim' },
                }
            },
            Python = {
                provideFormatter = true,
                pythonFormatter = "black"
            }
        }
    }
end


