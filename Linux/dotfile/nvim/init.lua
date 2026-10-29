vim.loader.enable() -- Bytecode cache of the lua files: faster start

require 'basics.options'
require 'basics.keymaps' -- Sets the leader key (before lazy)
require 'basics.autocmds'

-- Set up the Lazy plugin manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
    local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath})
    if vim.v.shell_error ~= 0 then
        error('Error cloning lazy.nvim:\n' .. out)
    end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
    --require 'themes.nord',
    require 'themes.rose-pine',
    --require 'themes.oldworld',
    --require 'themes.catppuccin',
    --require 'themes.tokyodark',
    --require 'themes.cyberdream',
    --require 'themes.oxocarbon',
    --require 'themes.deepwhite',

    require 'plugins.auto-completion',
    --require 'plugins.neotree', -- Replaced by tree/ (Ctrl+T)
    --require 'plugins.header',
    require 'plugins.treesitter',
}, {
    rtp = { disabled_plugins = { 'gzip', 'tarPlugin', 'tohtml', 'tutor', 'zipPlugin', 'rplugin', 'spellfile', 'netrwPlugin' } },
    change_detection = { enabled = false }, -- No file watcher
    checker = { enabled = false },
})

-- Completion helpers, help under the mouse, warnings & errors (need cmp, loaded above)
require('matching.include_trigger').setup() -- cmp is only loaded at the first insert / command line
require('matching.hover').setup()
require('matching.checks').setup()

-- Update the date of xartania header
require 'header.update'
