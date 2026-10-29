-- The content of an #include opens by itself as soon as the cursor is between the < > or the " " (mouse included)
-- It does not come back after Esc / Ctrl+E / an accepted choice, until a letter is typed or the cursor leaves the line
local M = {}

local dismissed = nil -- Line where the menu was dismissed

local function row() return vim.api.nvim_win_get_cursor(0)[1] end

local function in_include()
    local filetype = vim.bo.filetype
    if filetype ~= 'c' and filetype ~= 'cpp' then return false end
    local before = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_win_get_cursor(0)[2])
    return before:match('^%s*#%s*include%s*[<"][^<>"]*$') ~= nil
end

local function open()
    local cmp = require('cmp')
    if cmp.visible() or dismissed == row() or not in_include() then return end
    cmp.complete({ config = { sources = { { name = 'include' } } } })
end

function M.dismiss() dismissed = row() end

function M.setup()
    local group = vim.api.nvim_create_augroup('IncludeTrigger', { clear = true })

    vim.api.nvim_create_autocmd({ 'InsertEnter', 'CursorMovedI' }, {
        group = group,
        callback = function()
            if dismissed and dismissed ~= row() then dismissed = nil end -- The cursor left the line
            vim.schedule(open)
        end,
    })
    vim.api.nvim_create_autocmd('TextChangedI', { group = group, callback = function() dismissed = nil end }) -- A key was typed
    vim.api.nvim_create_autocmd('InsertLeave', {
        group = group,
        callback = function()
            if vim.api.nvim_get_current_line():match('^%s*#%s*include') then M.dismiss() end
        end,
    })

    vim.api.nvim_create_autocmd('InsertEnter', { -- cmp is loaded by then
        group = group, once = true,
        callback = function()
            require('cmp').event:on('confirm_done', function(event)
                local label = event.entry and event.entry.completion_item and event.entry.completion_item.label or ''
                vim.schedule(function()
                    if event.entry.source.name ~= 'include' then return end
                    if label:sub(-1) == '/' then dismissed = nil; open() else M.dismiss() end -- A folder: its content follows
                end)
            end)
        end,
    })
end

return M
