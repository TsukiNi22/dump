-- Trailing spaces in a soft red (rose-pine love at ~45% over the background)
local group = vim.api.nvim_create_augroup('TrailingSpace', { clear = true })
local skipped = { 'help', 'lazy', 'neo-tree', 'netrw', 'filetree' }

local function set_highlight()
    vim.api.nvim_set_hl(0, 'TrailingSpace', { bg = '#6b2f45', ctermbg = 'darkred' })
end
set_highlight()
vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = set_highlight }) -- :colorscheme clears the group

-- One match per window, updated when the window shows an other buffer
local function update_match(insert)
    local win = vim.api.nvim_get_current_win()
    if vim.w[win].trailing_space_match then
        pcall(vim.fn.matchdelete, vim.w[win].trailing_space_match)
        vim.w[win].trailing_space_match = nil
    end
    if vim.bo.buftype ~= '' or vim.tbl_contains(skipped, vim.bo.filetype) then return end

    -- In insert mode the spaces just typed at the cursor are not marked
    local pattern = insert and [[\s\+\%#\@<!$]] or [[\s\+$]]
    vim.w[win].trailing_space_match = vim.fn.matchadd('TrailingSpace', pattern)
end

vim.api.nvim_create_autocmd({ 'VimEnter', 'WinEnter', 'BufWinEnter', 'InsertLeave' }, {
    group = group,
    callback = function() update_match(false) end,
})
vim.api.nvim_create_autocmd('InsertEnter', { group = group, callback = function() update_match(true) end })
