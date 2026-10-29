return {
    {
        'hrsh7th/nvim-cmp',
        event = { 'InsertEnter', 'CmdlineEnter' }, -- Not at start: the first insert / ':' / '/' loads it
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
            -- After the first draw, and not for C / C++: their 800 ms of generic snippets froze the first completion (the [std] source
            -- already offers the skeletons of C / C++)
            vim.schedule(function() require("luasnip.loaders.from_vscode").lazy_load({ exclude = { 'c', 'cpp' } }) end)

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
                performance = {
                    debounce = 8,          -- ms before the menu is refreshed after a source answered (default 60)
                    throttle = 8,
                    fetching_timeout = 80, -- A slow source is left behind instead of blocking the menu
                    max_view_entries = 25,
                },
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
                    { name = 'symbols', dup = 0, max_item_count = 300 }, -- Functions, types, variables of the file and of its includes
                    { name = 'members' },   -- After '.', '->' and '::'
                    { name = 'luasnip', max_item_count = 20 },
                    { name = 'path' },
                    { name = 'words', dup = 0, max_item_count = 200 },   -- Words of the file, after all the others
                },
            })

            -- cmp.visible(), cmp.complete()... wait up to 1 s (vim.wait) for the filtering of the menu to end before answering:
            -- while it waits no key is read, that was the freeze. The answer is given at once with the state of the moment.
            cmp.core.filter.sync = function() end

            -- Side of the menu: below the cursor when it fits, else above, else the side with the most room (the list is
            -- then shorter and scrolls). cmp only knows "can it fit below": the room is given to it through max_height
            local entries_view = require('cmp.view.custom_entries_view')
            local open_view = entries_view.open
            entries_view.open = function(self, offset, entries)
                local config = require('cmp.config').get()
                local row = require('cmp.utils.api').get_screen_cursor()[1]
                local bottom = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
                local below, above = bottom - row, row - 1
                local want = math.min(#entries, vim.o.pumheight > 0 and vim.o.pumheight or 10)
                local side = 'below'
                if below < want then
                    side = (above >= want or above > below) and 'above' or 'below'
                end
                config.view.entries.vertical_positioning = side
                config.window.completion.max_height = math.max(1, math.min(want, side == 'below' and below or above))
                return open_view(self, offset, entries)
            end

            -- The documentation window is built when the selection stays still, not for each entry passed over
            local docs_view = require('cmp.view.docs_view')
            local open_docs = docs_view.open
            local docs_timer = vim.uv.new_timer()
            docs_view.open = function(self, e, view)
                docs_timer:stop()
                docs_timer:start(90, 0, vim.schedule_wrap(function()
                    if cmp.core.view:visible() then open_docs(self, e, view) end -- Not cmp.visible(): it blocks
                end))
            end

            -- Nothing to propose when the only choices are the word already typed, exactly
            cmp.event:on('menu_opened', function()
                local entries = cmp.get_entries()
                local typed = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_win_get_cursor(0)[2]):match('[%w_]*$')
                if typed == '' or #entries == 0 then return end
                for _, entry in ipairs(entries) do
                    if entry:get_word() ~= typed then return end
                end
                vim.schedule(cmp.close)
            end)

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
        ft = { 'c', 'cpp', 'lua' }, -- Only when such a file is opened
        config = function()
            local capabilities = require('cmp_nvim_lsp').default_capabilities()

            -- Only the servers installed on the machine (no error at each file opened otherwise)
            local servers = {
                lua_ls = 'lua-language-server',
                clangd = 'clangd',
            }
            -- clangd: the compile database found (CMake, bear...) else the include / src folders above the file as flags
            vim.lsp.config('clangd', {
                cmd = function(dispatchers, config)
                    local root = config.root_dir or vim.fn.getcwd()
                    local project = require('matching.project')
                    local command = {
                        'clangd', '--background-index', '--background-index-priority=low', '--header-insertion=never',
                        '--pch-storage=memory', '--clang-tidy=false', '--limit-results=100', '--malloc-trim',
                        '-j=' .. math.max(2, math.floor((vim.uv.available_parallelism() or 4) / 2)),
                    }
                    local env
                    local db = project.compile_db(root .. '/x')
                    if db then
                        table.insert(command, '--compile-commands-dir=' .. vim.fs.dirname(db))
                    else
                        local add = {}
                        for _, dir in ipairs(project.dirs(root .. '/x')) do table.insert(add, '"-I' .. dir .. '"') end
                        local home = vim.fn.stdpath('cache') .. '/clangd-' .. vim.fn.sha256(root):sub(1, 12)
                        vim.fn.mkdir(home .. '/clangd', 'p')
                        vim.fn.writefile({ 'CompileFlags:', '  Add: [' .. table.concat(add, ', ') .. ']' }, home .. '/clangd/config.yaml')
                        env = { XDG_CONFIG_HOME = home }
                    end
                    return vim.lsp.rpc.start(command, dispatchers, { env = env })
                end,
            })
            for server, cmd in pairs(servers) do
                if vim.fn.executable(cmd) == 1 then
                    vim.lsp.config(server, { capabilities = capabilities })
                    vim.lsp.enable(server)
                end
            end
        end,
    },
}
