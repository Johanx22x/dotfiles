--[[
██╗░░░░░░█████╗░███╗░░██╗░██████╗░██╗░░░██╗░█████╗░░██████╗░███████╗
██║░░░░░██╔══██╗████╗░██║██╔════╝░██║░░░██║██╔══██╗██╔════╝░██╔════╝
██║░░░░░███████║██╔██╗██║██║░░██╗░██║░░░██║███████║██║░░██╗░█████╗░░
██║░░░░░██╔══██║██║╚████║██║░░╚██╗██║░░░██║██╔══██║██║░░╚██╗██╔══╝░░
███████╗██║░░██║██║░╚███║╚██████╔╝╚██████╔╝██║░░██║╚██████╔╝███████╗
╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝░╚═════╝░░╚═════╝░╚═╝░░╚═╝░╚═════╝░╚══════╝
░██████╗███████╗██████╗░██╗░░░██╗███████╗██████╗░
██╔════╝██╔════╝██╔══██╗██║░░░██║██╔════╝██╔══██╗
╚█████╗░█████╗░░██████╔╝╚██╗░██╔╝█████╗░░██████╔╝
░╚═══██╗██╔══╝░░██╔══██╗░╚████╔╝░██╔══╝░░██╔══██╗
██████╔╝███████╗██║░░██║░░╚██╔╝░░███████╗██║░░██║
╚═════╝░╚══════╝╚═╝░░╚═╝░░░╚═╝░░░╚══════╝╚═╝░░╚═╝
██████╗░██████╗░░█████╗░████████╗░█████╗░░█████╗░░█████╗░██╗░░░░░
██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██║░░░░░
██████╔╝██████╔╝██║░░██║░░░██║░░░██║░░██║██║░░╚═╝██║░░██║██║░░░░░
██╔═══╝░██╔══██╗██║░░██║░░░██║░░░██║░░██║██║░░██╗██║░░██║██║░░░░░
██║░░░░░██║░░██║╚█████╔╝░░░██║░░░╚█████╔╝╚█████╔╝╚█████╔╝███████╗
╚═╝░░░░░╚═╝░░╚═╝░╚════╝░░░░╚═╝░░░░╚════╝░░╚════╝░░╚════╝░╚══════╝]]--

local servers = {
    "gopls",
    "jedi_language_server",
    "lua_ls",
    "clangd",
    "hls",
    "tsserver",
    "jdtls",
    "kotlin_language_server",
    "rust_analyzer",
}

local function on_attach()
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references)
    vim.keymap.set('n', '<leader>f', vim.lsp.buf.format)
end

for _, server in ipairs(servers) do
    require("lspconfig")[server].setup {
        on_attach = on_attach,
        flags = {
            debounce_text_changes = 150,
        },
        settings = {
            Lua = {
                runtime = {
                    version = 'LuaJIT',
                },
                diagnostics = {
                    globals = { 'vim' },
                },
                workspace = {
                    library = vim.api.nvim_get_runtime_file("", true),
                },
                telemetry = {
                    enable = false,
                },
            },
            Python = {
                provideFormatter = true,
                pythonFormatter = "black"
            },
            ["rust-analyzer"] = {
                imports = {
                    granularity = {
                        group = "module",
                    },
                    prefix = "self",
                },
                cargo = {
                    buildScripts = {
                        enable = true,
                    },
                },
                procMacro = {
                    enable = true
                },
            },
        }
    }
end
