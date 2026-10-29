return {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-tree/nvim-web-devicons',
        'MunifTanjim/nui.nvim'
    },
    opts = {
        default_component_configs = {
            -- No Nerd Font needed: plain characters everywhere
            icon = {
                folder_closed = '▸',
                folder_open = '▾',
                folder_empty = '▹',
                folder_empty_open = '▹',
                default = '·',
                provider = function(icon) return icon end, -- No devicons
            },
            git_status = {
                symbols = {
                    added = '+', modified = '~', deleted = '-', renamed = '»',
                    untracked = '?', ignored = '!', unstaged = '*', staged = '✓', conflict = '=',
                },
            },
            modified = { symbol = '●' },
        },
        window = {
            mappings = {
                ['<cr>'] = function(neo_state) require('tree').enter(neo_state) end,
                ['<c-t>'] = function() require('tree').close() end,
                ['q'] = function() require('tree').close() end,
                ['<esc>'] = 'noop', -- Does not hide the preview anymore
                ['l'] = 'toggle_node',
                ['P'] = { 'toggle_preview', config = { use_float = false } },
            },
        },
        event_handlers = {
            {
                -- '..' line above the root: Enter on the root line (or Backspace) goes up
                event = 'after_render',
                handler = function(neo_state)
                    local buf = neo_state.bufnr
                    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
                    local ns = vim.api.nvim_create_namespace('tree_up')
                    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
                    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
                        virt_lines = { { { '  ..  (go up: <BS> or Enter on the path below)', 'Comment' } } },
                        virt_lines_above = true,
                    })
                end,
            },
        },
        filesystem = {
            hijack_netrw_behavior = 'disabled', -- Keep :Ex (Ctrl+E) as it is
            follow_current_file = { enabled = true },
            filtered_items = { visible = true }, -- Show the hidden files
        },
    },
}
