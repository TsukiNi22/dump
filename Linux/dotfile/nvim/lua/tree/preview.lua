-- Preview of the entry under the cursor of the tree: text (highlighted), folder content, image (chafa), binary
local M = {}

local images = {
    png = true, jpg = true, jpeg = true, gif = true, webp = true, bmp = true, svg = true, avif = true, ico = true,
    tiff = true, tif = true,
}
local max_bytes = 65536
local max_lines = 400

local job = nil       -- Running chafa
local token = 0       -- Only the latest preview is displayed
local current = nil   -- Buffer of the displayed preview

M.images = images

local function human(size)
    local units = { 'B', 'KB', 'MB', 'GB' }
    local unit = 1
    while size >= 1024 and unit < #units do size = size / 1024; unit = unit + 1 end
    return unit == 1 and string.format('%d %s', size, units[unit]) or string.format('%.1f %s', size, units[unit])
end
M.human = human

local function escape(text) return (text:gsub('%%', '%%%%')) end

local function new_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    return buf
end

local function set_lines(buf, lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

local function place(win, buf, title)
    local previous = current
    vim.api.nvim_win_set_buf(win, buf)
    current = buf
    if previous and previous ~= buf and vim.api.nvim_buf_is_valid(previous) then
        pcall(vim.api.nvim_buf_delete, previous, { force = true })
    end
    for option, value in pairs({ number = false, relativenumber = false, signcolumn = 'no', foldcolumn = '0',
        cursorline = false, wrap = false, list = false, colorcolumn = '' }) do
        vim.wo[win][option] = value
    end
    vim.wo[win].winbar = '%#Title# ' .. escape(title) .. ' '
end

local function folder(win, item)
    local names = {}
    local handle = vim.uv.fs_scandir(item.path)
    while handle do
        local name, type = vim.uv.fs_scandir_next(handle)
        if not name then break end
        table.insert(names, { name = name, dir = type == 'directory' })
    end
    table.sort(names, function(a, b)
        if a.dir ~= b.dir then return a.dir end
        return a.name:lower() < b.name:lower()
    end)
    local lines = {}
    for index, entry in ipairs(names) do
        if index > 200 then table.insert(lines, '  ...') break end
        table.insert(lines, '  ' .. (entry.dir and '▸ ' or '· ') .. entry.name .. (entry.dir and '/' or ''))
    end
    if #lines == 0 then lines = { '  (empty)' } end
    local buf = new_buffer()
    set_lines(buf, lines)
    place(win, buf, vim.fn.fnamemodify(item.path, ':t') .. '/  ' .. #names .. ' entries')
end

local function image(win, item, size)
    local buf = new_buffer()
    place(win, buf, vim.fn.fnamemodify(item.path, ':t') .. '  ' .. human(size))
    if vim.fn.executable('chafa') ~= 1 then
        vim.bo[buf].modifiable = true
        set_lines(buf, { '  chafa is not installed: no image preview' })
        return
    end

    local channel = vim.api.nvim_open_term(buf, {})
    local width = math.max(10, vim.api.nvim_win_get_width(win) - 1)
    local height = math.max(5, vim.api.nvim_win_get_height(win) - 1)
    local mine = token
    job = vim.system({ 'chafa', '-f', 'symbols', '--colors=full', '--animate=off', '--size=' .. width .. 'x' .. height,
        item.path }, { text = true }, function(result)
        vim.schedule(function()
            if mine ~= token or not vim.api.nvim_buf_is_valid(buf) then return end
            local text = result.code == 0 and result.stdout or ('  cannot display this image\r\n  ' .. (result.stderr or ''))
            pcall(vim.api.nvim_chan_send, channel, (text:gsub('\n', '\r\n')))
        end)
    end)
end

local function text(win, item, stat)
    local file = io.open(item.path, 'rb')
    local data = file and file:read(max_bytes) or ''
    if file then file:close() end

    local buf = new_buffer()
    if data:find('\0', 1, true) then
        set_lines(buf, { '  binary file', '  ' .. human(stat.size) })
        return place(win, buf, vim.fn.fnamemodify(item.path, ':t'))
    end

    local lines = vim.split(data, '\n', { plain = true })
    if #lines > max_lines then lines = vim.list_slice(lines, 1, max_lines) end
    set_lines(buf, lines)
    place(win, buf, vim.fn.fnamemodify(item.path, ':t') .. '  ' .. human(stat.size))
    local filetype = vim.filetype.match({ filename = item.path, contents = lines })
    if filetype then
        vim.bo[buf].filetype = filetype
        pcall(vim.treesitter.start, buf)
    end
end

function M.show(win, item)
    if not vim.api.nvim_win_is_valid(win) or not item then return end
    token = token + 1
    if job then pcall(function() job:kill(9) end) job = nil end

    local previous_buf = vim.api.nvim_win_get_buf(win)
    if item.parent or item.dir then return folder(win, item) end
    if item.none then return end

    local stat = vim.uv.fs_stat(item.path)
    if not stat then return end
    local extension = (item.path:match('%.(%w+)$') or ''):lower()
    if images[extension] then image(win, item, stat.size) else text(win, item, stat) end
    return previous_buf
end

function M.clear()
    token = token + 1
    if job then pcall(function() job:kill(9) end) job = nil end
    current = nil
end

return M
