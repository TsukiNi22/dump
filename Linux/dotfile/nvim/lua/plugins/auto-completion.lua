return {
    {
        'hrsh7th/nvim-cmp',
        lazy = false, -- Loaded at start: the completion of ':' and '/' works from the first use
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            'hrsh7th/cmp-cmdline',
            'L3MON4D3/LuaSnip', -- For snippets
            'rafamadriz/friendly-snippets', -- Predefined snippet collection
        },
        config = function()
            local cmp = require('cmp')
            local luasnip = require('luasnip')

            -- Load friendly snippets
            require("luasnip.loaders.from_vscode").lazy_load()

            require('matching.sources').register()

            cmp.setup({
                snippet = {
                    expand = function(args)
                        require('luasnip').lsp_expand(args.body) -- Snippet engine
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping(function()
                        require('matching.include_trigger').dismiss() -- No automatic menu again on this line
                        cmp.abort()
                    end, { 'i' }),
                    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept completion
                    ['<Tab>'] = cmp.mapping(function(fallback) -- Accepts the choice (like Enter), the arrows move in the menu
                        if cmp.visible() then
                            cmp.confirm({ select = true })
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ['<S-Tab>'] = cmp.mapping(function(fallback)
                        if luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                formatting = {
                    fields = { 'abbr', 'kind', 'menu' },
                    format = require('matching.sources').format, -- Tag of the source: [kw] [inc] [sym] [file]...
                },
                sorting = {
                    comparators = require('matching.sources').comparators(), -- Special sources first, then c2dmp-hsm
                },
                sources = {
                    { name = 'nvim_lsp' },
                    { name = 'include' },   -- #include "..." / <...>
                    { name = 'keywords' },  -- Keywords and #directives
                    { name = 'common' },    -- [std] main, control structures, usual includes and calls
                    { name = 'symbols', dup = 0 }, -- Functions, types, variables of the file and of its includes
                    { name = 'members' },   -- After '.', '->' and '::'
                    { name = 'luasnip' },
                    { name = 'path' },
                    { name = 'words', dup = 0 },   -- Words of the file, after all the others
                },
            })

            -- Use cmp for `/`, `?` and `:` command-line completions
            cmp.setup.cmdline({ '/', '?' }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = 'buffer' }
                },
            })

            cmp.setup.cmdline(':', {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({
                    { name = 'path' }
                }, {
                    { name = 'cmdline' }
                }),
            })
        end,
    },
    {
        'neovim/nvim-lspconfig', -- Required for LSP
        config = function()
            local capabilities = require('cmp_nvim_lsp').default_capabilities()

            -- Only the servers installed on the machine (no error at each file opened otherwise)
            local servers = {
                lua_ls = 'lua-language-server',
                clangd = 'clangd',
            }
            for server, cmd in pairs(servers) do
                if vim.fn.executable(cmd) == 1 then
                    vim.lsp.config(server, { capabilities = capabilities })
                    vim.lsp.enable(server)
                end
            end
        end,
    },
}
