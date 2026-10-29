-- Help of a function / type / macro: signature and comment (from the file and its includes) under the mouse, or K
local M = {}

local index = require('matching.index')
local delay = 350 -- Milliseconds of rest before the help appears

local timer = vim.uv.new_timer()
local float = nil -- { win, word }

local function close()
    if float and vim.api.nvim_win_is_valid(float.win) then vim.api.nvim_win_close(float.win, true) end
    float = nil
end

local function word_at(buf, line, column) -- column: 1-based byte of the text
    local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ''
    for start, finish in text:gmatch('()[%w_]+()') do
        if column >= start and column < finish then return text:sub(start, finish - 1) end
    end
end

local function show(entry, relative)
    local lines = vim.split(require('matching.doc').markdown(entry), '\n')
    local width = 20
    for _, line in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(line)) end
    width = math.min(width, 80)
    for index, line in ipairs(lines) do
        if line == '---' then lines[index] = ('─'):rep(width) end -- The rule of the markdown
    end
    local height = 0
    for _, line in ipairs(lines) do height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width)) end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = 'markdown'
    pcall(vim.treesitter.start, buf, 'markdown')
    local win = vim.api.nvim_open_win(buf, false, {
        relative = relative, row = 1, col = 0, width = width, height = math.min(height, 20),
        style = 'minimal', border = 'rounded', focusable = false, noautocmd = true,
    })
    vim.wo[win].wrap = true
    vim.wo[win].conceallevel = 2 -- Hides the markers of the markdown (```, **, `)
    return win
end

-- Help of the word under the mouse
local function show_at_mouse()
    local pos = vim.fn.getmousepos()
    if pos.winid == 0 or pos.line < 1 or pos.column < 1 then return end
    if float and pos.winid == float.win then return end

    local buf = vim.api.nvim_win_get_buf(pos.winid)
    if vim.bo[buf].buftype ~= '' or not index.supported(buf) then return end
    local word = word_at(buf, pos.line, pos.column)
    if not word or (float and float.word == word) then return end

    close()
    local entry = index.lookup(buf, word)
    if entry then float = { win = show(entry, 'mouse'), word = word } end
end

local function on_move()
    local pos = vim.fn.getmousepos()
    if float and pos.winid ~= float.win and pos.winid ~= 0 then
        local buf = vim.api.nvim_win_get_buf(pos.winid)
        if word_at(buf, pos.line, pos.column) ~= float.word then close() end
    end
    timer:stop()
    timer:start(delay, 0, vim.schedule_wrap(show_at_mouse))
end

-- K: help of the word under the cursor (the usual K when there is none)
local function on_key()
    local buf = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local word = index.supported(buf) and word_at(buf, cursor[1], cursor[2] + 1)
    local entry = word and index.lookup(buf, word)
    if not entry then return vim.cmd('normal! K') end
    close()
    float = { win = show(entry, 'cursor'), word = word }
end

function M.setup()
    vim.o.mousemoveevent = true
    vim.keymap.set({ 'n', 'i', 'v' }, '<MouseMove>', on_move, { silent = true })
    vim.keymap.set('n', 'K', on_key, { silent = true })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'InsertLeave', 'BufLeave', 'WinScrolled' }, {
        group = vim.api.nvim_create_augroup('HoverHelp', { clear = true }),
        callback = close,
    })
end

return M
