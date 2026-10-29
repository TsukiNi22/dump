-- File browser as a state of the window (like :Ex), one folder at a time (only the visible folder is read)
-- Left: the folder with '..' always first, right: preview (text, folder, image)
--   Enter / l: open or go into   BS / h / -: go up   /: filter (r: at the start = recursive)   .: hidden files
--   a: new   R: rename   D: delete   r: refresh   q / Ctrl+T: close
local M = {}

local preview = require('tree.preview')

local state = nil -- See open()
local namespace = vim.api.nvim_create_namespace('tree')
local saved_options = { 'number', 'relativenumber', 'signcolumn', 'foldcolumn', 'cursorline', 'wrap', 'list',
    'winbar', 'winhighlight', 'spell', 'colorcolumn' }

local function is_open() return state ~= nil and vim.api.nvim_win_is_valid(state.left) end
local function escape(text) return (text:gsub('%%', '%%%%')) end
local function join(dir, name) return dir == '/' and ('/' .. name) or (dir .. '/' .. name) end
local function tilde(path) return (path:gsub('^' .. vim.pesc(vim.env.HOME), '~')) end

--------------------------------------------------------------------------------
-- Content
--------------------------------------------------------------------------------
local function list(dir, show_hidden)
    local entries = {}
    local handle = vim.uv.fs_scandir(dir)
    while handle do
        local name, type = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if show_hidden or name:sub(1, 1) ~= '.' then
            local path = join(dir, name)
            if type == 'link' then
                local stat = vim.uv.fs_stat(path)
                type = stat and stat.type or 'file'
            end
            table.insert(entries, { name = name, path = path, dir = type == 'directory' })
        end
    end
    table.sort(entries, function(a, b)
        if a.dir ~= b.dir then return a.dir end
        return a.name:lower() < b.name:lower()
    end)
    return entries
end

local function subsequence(term, text)
    local position = 1
    for char in term:gmatch('.') do
        local found = text:find(char, position, true)
        if not found then return false end
        position = found + 1
    end
    return true
end

-- Entries of the filter: names holding the typed text (or its letters in order), the first ones are the best
local function filtered(entries, term, key)
    if term == '' then return entries end
    term = term:lower()
    local best, others = {}, {}
    for _, entry in ipairs(entries) do
        local name = (key and entry[key] or entry.name):lower()
        if name:find(term, 1, true) then table.insert(best, entry)
        elseif subsequence(term, name) then table.insert(others, entry) end
    end
    return vim.list_extend(best, others)
end

-- Recursive filter (r:...): the files below the folder, listed once by rg / find
local function load_recursive(dir)
    if state.recursive and state.recursive.dir == dir then return end
    state.recursive = { dir = dir, files = {}, loading = true }
    local command = vim.fn.executable('rg') == 1
        and { 'rg', '--files', '--hidden', '--glob', '!.git', '--sort', 'path' }
        or { 'find', '.', '-type', 'f', '-not', '-path', '*/.git/*' }
    vim.system(command, { cwd = dir, text = true }, function(result)
        vim.schedule(function()
            if not state or not state.recursive or state.recursive.dir ~= dir then return end
            local files = {}
            for relative in (result.stdout or ''):gmatch('[^\n]+') do
                relative = relative:gsub('^%./', '')
                table.insert(files, { name = relative, path = join(dir, relative), dir = false })
                if #files >= 20000 then break end
            end
            state.recursive = { dir = dir, files = files }
            M.render()
        end)
    end)
end

local function visible()
    local term = state.filter
    if term:sub(1, 2) == 'r:' then
        load_recursive(state.dir)
        return vim.list_slice(filtered(state.recursive.files, term:sub(3)), 1, 500)
    end
    return filtered(state.entries, term)
end

--------------------------------------------------------------------------------
-- Display
--------------------------------------------------------------------------------
local function set_highlights()
    local function color(group, link, extra)
        vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', { link = link }, extra or {}))
    end
    color('TreeUp', 'Special', { bold = true })
    color('TreeDir', 'Directory', { bold = true })
    color('TreeFilter', 'WarningMsg', { bold = true })
end

local function update_winbar()
    local text = '%#TreeUp#%@v:lua.TreeUp@ ▴ .. %X%#TreeDir# ' .. escape(tilde(state.dir)) .. ' '
    if state.filter ~= '' then
        local loading = state.filter:sub(1, 2) == 'r:' and state.recursive and state.recursive.loading
        text = text .. '%=%#TreeFilter# / ' .. escape(state.filter) .. (loading and ' (searching...)' or '') .. ' '
    end
    vim.wo[state.left].winbar = text
end

local function update_preview()
    if not is_open() then return end
    local row = vim.api.nvim_win_get_cursor(state.left)[1]
    preview.show(state.right, state.items[row])
end

local function schedule_preview()
    state.pending = (state.pending or 0) + 1
    local mine = state.pending
    vim.defer_fn(function()
        if state and state.pending == mine then update_preview() end
    end, 40)
end

function M.render(select_path)
    if not is_open() then return end
    local buf = state.buf
    local entries = visible()

    local lines, items, starts = { '  ..' }, { { parent = true, path = vim.fs.dirname(state.dir) } }, {}
    for _, entry in ipairs(entries) do
        local extension = (entry.name:match('%.(%w+)$') or ''):lower()
        local icon = entry.dir and '▸' or (preview.images[extension] and '▣' or '·')
        local prefix = '  ' .. icon .. ' '
        table.insert(lines, prefix .. entry.name .. (entry.dir and '/' or ''))
        table.insert(items, entry)
        starts[#items] = #prefix -- Byte where the name begins
    end
    if #entries == 0 then
        local loading = state.recursive and state.recursive.loading and state.filter:sub(1, 2) == 'r:'
        table.insert(lines, loading and '  searching...' or (state.filter ~= '' and '  no match' or '  empty'))
        table.insert(items, { none = true })
    end

    -- The cursor stays on the same entry
    local row = 1 + (#entries > 0 and 1 or 0)
    local wanted = select_path or (state.items and state.items[vim.api.nvim_win_get_cursor(state.left)[1]] or {}).path
    if wanted then
        for index, item in ipairs(items) do if item.path == wanted and not item.parent then row = index break end end
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    state.items = items

    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    vim.api.nvim_buf_set_extmark(buf, namespace, 0, 0, { line_hl_group = 'TreeUp', end_row = 0 })
    for index, entry in ipairs(items) do
        local line = index - 1
        if entry.name then
            local start = starts[index]
            local hidden = entry.name:find('^%.') ~= nil
            local group = entry.dir and 'Directory' or (hidden and 'Comment' or 'Normal')
            vim.api.nvim_buf_set_extmark(buf, namespace, line, start, { end_col = #lines[index], hl_group = group })
            local directory = entry.name:match('^(.*/)')
            if directory then
                vim.api.nvim_buf_set_extmark(buf, namespace, line, start, { end_col = start + #directory, hl_group = 'Comment' })
            end
            if not entry.dir and #items < 400 then
                local stat = vim.uv.fs_stat(entry.path)
                if stat then
                    vim.api.nvim_buf_set_extmark(buf, namespace, line, 0, {
                        virt_text = { { preview.human(stat.size) .. ' ', 'Comment' } }, virt_text_pos = 'right_align',
                    })
                end
            end
        else
            vim.api.nvim_buf_set_extmark(buf, namespace, line, 0, { line_hl_group = 'Comment' })
        end
    end

    vim.api.nvim_win_set_cursor(state.left, { math.min(row, #lines), 0 })
    update_winbar()
    schedule_preview()
end

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------
function M.go(dir, select_path)
    dir = vim.fs.normalize(dir)
    if vim.fn.isdirectory(dir) ~= 1 then return end
    state.dir = dir
    state.filter = ''
    state.recursive = nil
    state.entries = list(dir, state.show_hidden)
    state.items = nil
    M.render(select_path)
end

function M.up()
    if not is_open() then return end
    local parent = vim.fs.dirname(state.dir)
    if parent == state.dir then return end
    M.go(parent, state.dir) -- The cursor lands on the folder we come from
end

local function current_item() return state.items[vim.api.nvim_win_get_cursor(state.left)[1]] end

function M.enter()
    if not is_open() then return end
    local item = current_item()
    if not item or item.none then return end
    if item.parent then return M.up() end
    if item.dir then return M.go(item.path) end
    M.open_file(item.path)
end

function M.open_file(path)
    M.close()
    vim.cmd.edit(vim.fn.fnameescape(path)) -- Special characters (spaces, accents...) in the name
end

function M.set_filter(text)
    if not is_open() then return end
    state.filter = text
    if text:sub(1, 2) ~= 'r:' then state.recursive = nil end
    M.render()
end

function M.get() return state end

--------------------------------------------------------------------------------
-- Filter: / opens a line at the bottom, the list follows what is typed, 'r:' at the start = recursive
--------------------------------------------------------------------------------
function M.prompt()
    if not is_open() then return end
    local tree_win = state.left
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'prompt'
    vim.bo[buf].bufhidden = 'wipe'
    vim.fn.prompt_setprompt(buf, '/ ')

    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'win', win = tree_win, row = vim.api.nvim_win_get_height(tree_win) - 1, col = 0,
        width = vim.api.nvim_win_get_width(tree_win), height = 1, style = 'minimal', border = 'none', zindex = 60,
    })
    vim.wo[win].winhighlight = 'Normal:PmenuSel'

    local function leave(clear)
        if clear then state.filter = '' ; state.recursive = nil end
        vim.cmd('stopinsert')
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if is_open() then
            vim.api.nvim_set_current_win(tree_win)
            M.render()
        end
    end

    vim.fn.prompt_setcallback(buf, function() leave(false) end) -- Enter: keep the filter
    for _, key in ipairs({ '<Esc>', '<C-c>' }) do
        vim.keymap.set({ 'i', 'n' }, key, function() leave(true) end, { buffer = buf, nowait = true })
    end
    vim.api.nvim_create_autocmd('TextChangedI', {
        buffer = buf,
        callback = function()
            local text = (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''):sub(3)
            M.set_filter(text)
        end,
    })
    vim.cmd('startinsert')
    if state.filter ~= '' then vim.api.nvim_feedkeys(state.filter, 'n', false) end
end

--------------------------------------------------------------------------------
-- Actions on the files
--------------------------------------------------------------------------------
local function refresh(select_path)
    state.entries = list(state.dir, state.show_hidden)
    state.recursive = nil
    M.render(select_path)
end

local function target()
    local item = current_item()
    return item and not item.parent and not item.none and item or nil
end

local actions = {
    create = function()
        local name = vim.fn.input('New (end with / for a folder): ')
        if name == '' then return end
        local path = join(state.dir, name)
        if name:sub(-1) == '/' then vim.fn.mkdir(path, 'p')
        else
            vim.fn.mkdir(vim.fs.dirname(path), 'p')
            local file = io.open(path, 'a')
            if file then file:close() end
        end
        refresh(path:gsub('/$', ''))
    end,
    rename = function()
        local item = target()
        if not item then return end
        local name = vim.fn.input('Rename to: ', item.name)
        if name == '' or name == item.name then return end
        vim.uv.fs_rename(item.path, join(state.dir, name))
        refresh(join(state.dir, name))
    end,
    delete = function()
        local item = target()
        if not item then return end
        if vim.fn.confirm('Delete ' .. item.name .. ' ?', '&Yes\n&No', 2) ~= 1 then return end
        vim.fn.delete(item.path, item.dir and 'rf' or '')
        refresh()
    end,
}

--------------------------------------------------------------------------------
-- Open / close
--------------------------------------------------------------------------------
local function set_keys(buf)
    local function map(keys, action)
        for _, key in ipairs(type(keys) == 'table' and keys or { keys }) do
            vim.keymap.set('n', key, action, { buffer = buf, nowait = true, silent = true })
        end
    end
    map({ '<CR>', 'l', '<Right>', '<2-LeftMouse>' }, M.enter)
    map({ '<BS>', 'h', '-', '<Left>' }, M.up)
    map('/', M.prompt)
    map('<Esc>', function() -- Clears the filter, never hides the preview
        if state.filter ~= '' then state.filter = ''; state.recursive = nil; M.render() end
    end)
    map('.', function() state.show_hidden = not state.show_hidden; refresh() end)
    map('r', function() refresh() end)
    map('a', actions.create)
    map('R', actions.rename)
    map('D', actions.delete)
    map({ 'q', '<C-t>' }, M.close)
    map({ '<ScrollWheelLeft>', '<ScrollWheelRight>', '<S-ScrollWheelUp>', '<S-ScrollWheelDown>' }, '<Nop>') -- No sideways moves
end

local function apply_width()
    if is_open() then vim.api.nvim_win_set_width(state.left, math.max(30, math.floor(vim.o.columns * 0.35))) end
end

function M.close()
    if not state then return end
    local s = state
    state = nil
    pcall(vim.api.nvim_del_augroup_by_id, s.group)
    preview.clear()
    if vim.api.nvim_win_is_valid(s.right) then vim.api.nvim_win_close(s.right, true) end
    if vim.api.nvim_win_is_valid(s.left) then
        for option, value in pairs(s.options) do vim.wo[s.left][option] = value end
        if vim.api.nvim_buf_is_valid(s.origin) then vim.api.nvim_win_set_buf(s.left, s.origin) end
        vim.api.nvim_set_current_win(s.left)
    end
    if vim.api.nvim_buf_is_valid(s.buf) then pcall(vim.api.nvim_buf_delete, s.buf, { force = true }) end
end

function M.open()
    if is_open() then return M.close() end

    local left = vim.api.nvim_get_current_win()
    local origin = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(origin)
    local from_file = name ~= '' and vim.fn.filereadable(name) == 1
    local dir = from_file and vim.fs.dirname(vim.fn.fnamemodify(name, ':p')) or vim.fn.getcwd()

    vim.cmd('vsplit') -- The new window on the right shows the preview
    local right = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(left)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = 'filetree'
    vim.bo[buf].modifiable = false

    local options = {}
    for _, option in ipairs(saved_options) do options[option] = vim.wo[left][option] end
    vim.api.nvim_win_set_buf(left, buf)
    for option, value in pairs({ number = false, relativenumber = false, signcolumn = 'no', foldcolumn = '0',
        cursorline = true, wrap = false, list = false, spell = false, colorcolumn = '',
        winhighlight = 'Normal:NormalFloat,CursorLine:PmenuSel,EndOfBuffer:NormalFloat' }) do
        vim.wo[left][option] = value
    end

    local group = vim.api.nvim_create_augroup('Tree', { clear = true })
    state = {
        left = left, right = right, origin = origin, buf = buf, group = group, dir = dir, filter = '',
        show_hidden = true, options = options,
    }
    apply_width()
    set_highlights()
    set_keys(buf)

    vim.api.nvim_create_autocmd('CursorMoved', {
        group = group, buffer = buf,
        callback = function()
            local cursor = vim.api.nvim_win_get_cursor(state.left)
            if cursor[2] ~= 0 then vim.api.nvim_win_set_cursor(state.left, { cursor[1], 0 }) end -- Only the lines, not the columns
            schedule_preview()
        end,
    })
    vim.api.nvim_create_autocmd('VimResized', { group = group, callback = apply_width })
    vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = set_highlights })
    vim.api.nvim_create_autocmd('WinClosed', { -- :q in the tree: the preview goes away with it
        group = group,
        callback = function(args)
            if state and tonumber(args.match) == state.left then
                local right_win = state.right
                state = nil
                preview.clear()
                if vim.api.nvim_win_is_valid(right_win) then vim.api.nvim_win_close(right_win, true) end
            end
        end,
    })

    M.go(dir, from_file and vim.fn.fnamemodify(name, ':p') or nil)
end

-- Click on the '..' of the top bar
function _G.TreeUp()
    vim.schedule(M.up)
    return ''
end

return M
