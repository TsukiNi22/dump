-- Set leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Disable the spacebar key's default behavior in Normal and Visual modes
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', {silent = true})

local opts = {noremap = true, silent = true}

-- Basic -> leader
vim.keymap.set('n', '<leader>s', '<cmd>so<CR>', opts)       --Source
vim.keymap.set('n', '<leader>e', '<cmd>Ex<CR>', opts)       --Go to file explorer
vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', opts)        --Save
vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', opts)        --Leave
vim.keymap.set('n', '<leader>W', '<cmd>wq<CR>', opts)       --Save & Leave

-- Basic -> Ctrl
vim.keymap.set({'n', 'i'}, '<C-e>', '<cmd>Ex<CR>', opts)            --Go to file explorer
vim.keymap.set({'n', 'i'}, '<C-s>', '<cmd>w<CR>', opts)             --Save
vim.keymap.set({'n', 'i'}, '<C-q>', '<cmd>q<CR>', opts)             --Leave
vim.keymap.set({'n', 'i'}, '<C-x>', '<cmd>wq<CR>', opts)            --Save & Leave
vim.keymap.set({'n', 'i'}, '<C-z>', '<cmd>undo<CR>', opts)          --Undo
vim.keymap.set({'n', 'i'}, '<C-y>', '<cmd>redo<CR>', opts)          --Redo
vim.keymap.set({'n', 'i'}, '<C-S-Right>', '<cmd>next<CR>', opts)    --Next file
vim.keymap.set({'n', 'i'}, '<C-S-Left>', '<cmd>prev<CR>', opts)     --Previous file
vim.keymap.set({'n', 'v'}, '<C-l>', '$', opts)                      --End of line (normal/visual)
vim.keymap.set('i', '<C-l>', '<C-o>$', opts)                        --End of line (insert)
vim.keymap.set({'n', 'v'}, 'L', '^', opts)                          --Start of line (normal/visual, overrides default L = bottom of screen)

-- File tree with preview, a state of the window like Ex (the netrw one stays on Ctrl+E)
vim.keymap.set({'n', 'i'}, '<C-t>', require('tree').open, opts)         --File tree with preview

-- Warnings & errors are hidden by default (matching/checks.lua)
vim.keymap.set({'n', 'i'}, '<C-d>', function() require('matching.checks').toggle() end, opts) --Show/hide warnings & errors

-- Horizontal splits -> Ctrl+Shift+PageUp/PageDown
vim.keymap.set({'n', 'i'}, '<C-S-PageUp>',   '<cmd>topleft split<CR>',  opts)  --Horizontal split, new window at top
vim.keymap.set({'n', 'i'}, '<C-S-PageDown>', '<cmd>botright split<CR>', opts)  --Horizontal split, new window at bottom

-- Window switching -> Ctrl+Shift+arrows
vim.keymap.set({'n', 'i'}, '<C-S-Up>',    '<cmd>wincmd k<CR>', opts)    --Switch to window above
vim.keymap.set({'n', 'i'}, '<C-S-Down>',  '<cmd>wincmd j<CR>', opts)    --Switch to window below

-- Other
vim.keymap.set({'n', 'i'}, '<C-h>', require("header.choice"), opts)     -- Write header at the start of the file
vim.keymap.set({'n', 'i'}, '<C-f>', require("function.choice"), opts)   -- Write function proto at the curent position

-- Start & Stop the advanced color highlight of the current buffer (no error without parser)
local function toggle_treesitter()
    local buf = vim.api.nvim_get_current_buf()

    if vim.treesitter.highlighter.active[buf] then
        vim.treesitter.stop(buf)
        print("Treesitter OFF")
    elseif pcall(vim.treesitter.start, buf) then
        print("Treesitter ON")
    else
        print("Treesitter: no parser for '" .. vim.bo[buf].filetype .. "'")
    end
end
vim.keymap.set('n', '<C-p>', toggle_treesitter, opts)                   -- Start & Stop the advanced color highlight
