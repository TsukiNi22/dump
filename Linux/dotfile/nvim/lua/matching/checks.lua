-- Warnings and errors without any language server (toggled by Ctrl+D)
--   C / C++ : clang -fsyntax-only on the buffer (errors, warnings, #warning, #error, missing includes...)
--   others  : syntax errors found by treesitter
local project = require('matching.project')
local M = {}

local namespace = vim.api.nvim_create_namespace('checks')
local severity = vim.diagnostic.severity
local jobs = {}   -- buffer -> 'running' | 'again' (clang check in progress)
local timers = {} -- buffer -> debounce timer
local fast_timers = {}
local fast_namespace = vim.api.nvim_create_namespace('checks_fast')
local delay = 300

M.enabled = false

--------------------------------------------------------------------------------
-- Look
--------------------------------------------------------------------------------
local function set_highlights()
    -- Translucent backgrounds on the whole line: red = error, yellow = warning, violet = info, blue = hint
    local colors = {
        Error = { fg = '#eb6f92', bg = '#3a2230' }, Warn = { fg = '#f6c177', bg = '#3a3322' },
        Info = { fg = '#c4a7e7', bg = '#2c2640' }, Hint = { fg = '#9ccfd8', bg = '#223338' },
    }
    for name, color in pairs(colors) do
        vim.api.nvim_set_hl(0, 'DiagLine' .. name, { bg = color.bg })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualText' .. name, { fg = color.fg, bg = color.bg })
        vim.api.nvim_set_hl(0, 'DiagnosticUnderline' .. name, { undercurl = true, sp = color.fg })
    end
end

--------------------------------------------------------------------------------
-- C / C++
--------------------------------------------------------------------------------
local function word_end(buf, lnum, col)
    local text = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1] or ''
    local finish = text:match('^[%w_]+()', col + 1)
    return finish and (finish - 1) or col + 1
end

-- Heavy includes (libutils, STL...) make clang slow (seconds): they are compiled once into a precompiled header kept in
-- the cache folder, then only the body of the file is checked (loading the header still costs ~0.5 s for libutils)
local cache_dir = vim.fn.stdpath('cache') .. '/checks'
local building = {} -- pch key -> true while being built
local failed = {}   -- pch key -> true when the includes do not compile (a missing include...): full check instead
local checked = {}  -- buffer -> changedtick of the last check started

local function clean_cache()
    local handle = vim.uv.fs_scandir(cache_dir)
    local limit = os.time() - 7 * 24 * 3600
    while handle do
        local name = vim.uv.fs_scandir_next(handle)
        if not name then break end
        local stat = vim.uv.fs_stat(cache_dir .. '/' .. name)
        if stat and stat.mtime.sec < limit then os.remove(cache_dir .. '/' .. name) end
    end
end

local function options_of(buf, cpp, includes)
    local name = vim.api.nvim_buf_get_name(buf)
    local dir = vim.fn.fnamemodify(name, ':p:h')
    local cwd = vim.fn.getcwd()
    local options = {
        '-fno-color-diagnostics', '-fno-caret-diagnostics', '-ferror-limit=30', '-Wall', '-Wextra',
        '-Wno-pragma-once-outside-header', '-I', dir, '-I', dir .. '/include', '-I', cwd, '-I', cwd .. '/include',
    }
    -- Compile database (CMake, bear...) or, without it, the include / src folders above the file and the headers found
    vim.list_extend(options, project.options(name, includes, cpp))
    return options
end

local function diagnostics_of(buf, stderr)
    local diagnostics = {}
    for line in (stderr or ''):gmatch('[^\n]+') do
        local lnum, col, kind, message = line:match('^<stdin>:(%d+):(%d+): ([%a ]+): (.*)$')
        if lnum and (kind == 'error' or kind == 'fatal error' or kind == 'warning') then
            local row = tonumber(lnum) - 1
            local column = tonumber(col) - 1
            table.insert(diagnostics, {
                lnum = row, col = column, end_col = word_end(buf, row, column), source = 'clang',
                severity = kind == 'warning' and severity.WARN or severity.ERROR, message = message,
            })
        end
    end
    return diagnostics
end

-- Lines of the buffer where only the #include lines (prefix) or everything else (body) are kept: same line numbers
local function split_includes(buf)
    local prefix, body, count, paths = {}, {}, 0, {}
    for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line:match('^%s*#%s*include') then
            prefix[index], body[index] = line, ''
            count = count + 1
            table.insert(paths, line:match('^%s*#%s*include%s*["<]([^">]+)[">]'))
        else
            prefix[index], body[index] = '', line
        end
    end
    return table.concat(prefix, '\n') .. '\n', table.concat(body, '\n') .. '\n', count, paths
end

-- Everything needed to check a buffer with clang, and its precompiled header
local function plan_of(buf, filetype)
    local name = vim.api.nvim_buf_get_name(buf)
    local header = name:match('%.hpp$') or name:match('%.hh$') or name:match('%.hxx$') or name:match('%.h$')
    local cpp = filetype == 'cpp'
    local plan = {
        buf = buf, cpp = cpp, compiler = cpp and 'clang++' or 'clang',
        language = (cpp and 'c++' or 'c') .. (header and '-header' or ''),
    }
    plan.prefix, plan.body, plan.includes, plan.paths = split_includes(buf)
    plan.options = options_of(buf, cpp, plan.paths)
    plan.key = vim.fn.sha256(plan.compiler .. plan.language .. table.concat(plan.options, ' ') .. plan.prefix)
    plan.pch = cache_dir .. '/' .. plan.key .. '.pch'
    return plan
end

local function build_pch(plan)
    if building[plan.key] or failed[plan.key] or vim.uv.fs_stat(plan.pch) then return end
    building[plan.key] = true
    vim.fn.mkdir(cache_dir, 'p')
    clean_cache()
    local command = vim.fn.executable('nice') == 1 and { 'nice', '-n', '10' } or {}
    vim.list_extend(command, { plan.compiler, '-x', (plan.cpp and 'c++' or 'c') .. '-header' })
    vim.list_extend(command, plan.options)
    vim.list_extend(command, { '-o', plan.pch, '-' })
    vim.system(command, { stdin = plan.prefix, text = true }, function(result)
        vim.schedule(function()
            building[plan.key] = nil
            if result.code ~= 0 then failed[plan.key] = true; os.remove(plan.pch) end
        end)
    end)
end

-- done(): the check is over (a new one starts when the buffer changed meanwhile)
local function run_clang(buf, filetype, done)
    local plan = plan_of(buf, filetype)

    local function apply(result)
        if vim.api.nvim_buf_is_valid(buf) and M.enabled then
            vim.diagnostic.set(namespace, buf, diagnostics_of(buf, result.stderr))
            vim.diagnostic.set(fast_namespace, buf, {}) -- clang is the reference, the quick syntax check steps aside
        end
        done()
    end

    local function command_of(extra)
        local command = { plan.compiler, '-fsyntax-only', '-x', plan.language }
        vim.list_extend(command, plan.options)
        vim.list_extend(command, extra or {})
        table.insert(command, '-')
        return command
    end

    local function full()
        local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n') .. '\n'
        vim.system(command_of(), { stdin = text, text = true }, function(result) vim.schedule(function() apply(result) end) end)
    end

    if plan.includes == 0 or failed[plan.key] then return full() end

    if vim.uv.fs_stat(plan.pch) and not building[plan.key] then -- Not while it is being written
        vim.system(command_of({ '-include-pch', plan.pch }), { stdin = plan.body, text = true }, function(result)
            vim.schedule(function()
                if (result.stderr or ''):find('precompiled header', 1, true) then -- Out of date: a header changed
                    os.remove(plan.pch)
                    return full()
                end
                apply(result)
            end)
        end)
        return
    end

    full() -- First time: the complete check (slow), the precompiled header is built next to it
    build_pch(plan)
end

-- The precompiled header is prepared when the file is opened, the first check is then fast
function M.prewarm(buf)
    local filetype = vim.bo[buf].filetype
    if (filetype ~= 'c' and filetype ~= 'cpp') or vim.api.nvim_buf_get_name(buf) == '' then return end
    if vim.fn.executable(filetype == 'c' and 'clang' or 'clang++') ~= 1 then return end
    project.prepare(vim.api.nvim_buf_get_name(buf)) -- List of the headers of the project, in the background
    local plan = plan_of(buf, filetype)
    if plan.includes > 0 then build_pch(plan) end
end

--------------------------------------------------------------------------------
-- Other languages: syntax errors (treesitter)
--------------------------------------------------------------------------------
local function run_syntax(buf, target)
    local diagnostics = {}
    local ok, parser = pcall(vim.treesitter.get_parser, buf)
    local trees = ok and parser and parser:parse()
    if trees and trees[1] then
        local stack = { trees[1]:root() }
        while #stack > 0 and #diagnostics < 20 do
            local node = table.remove(stack)
            if node:type() == 'ERROR' or node:missing() then
                local row, col, end_row, end_col = node:range()
                table.insert(diagnostics, {
                    lnum = row, col = col, end_lnum = end_row, end_col = math.max(end_col, col + 1), source = 'treesitter',
                    severity = severity.ERROR, message = node:missing() and ('missing ' .. node:type()) or 'syntax error',
                })
            elseif node:has_error() then
                for child in node:iter_children() do table.insert(stack, child) end
            end
        end
    end
    vim.diagnostic.set(target or namespace, buf, diagnostics)
end

--------------------------------------------------------------------------------
-- Run, toggle
--------------------------------------------------------------------------------
local function clang_available(filetype)
    return (filetype == 'c' or filetype == 'cpp') and vim.fn.executable(filetype == 'c' and 'clang' or 'clang++') == 1
end

local function checkable(buf)
    return M.enabled and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= ''
end

-- Syntax errors at once (treesitter, a few milliseconds) while clang is still working
function M.quick(buf)
    if checkable(buf) and clang_available(vim.bo[buf].filetype) then run_syntax(buf, fast_namespace) end
end

function M.run(buf, force)
    buf = buf or vim.api.nvim_get_current_buf()
    if not checkable(buf) then return end
    local filetype = vim.bo[buf].filetype
    if clang_available(filetype) then
        local tick = vim.api.nvim_buf_get_changedtick(buf)
        if not force and checked[buf] == tick then return end -- Nothing changed since the last check
        -- Never cancelled: a check that is running finishes (its result is shown), then one more runs if the buffer changed
        if jobs[buf] then jobs[buf] = 'again' return end
        jobs[buf] = 'running'
        checked[buf] = tick
        run_clang(buf, filetype, function()
            local again = jobs[buf] == 'again'
            jobs[buf] = nil
            if again and vim.api.nvim_buf_is_valid(buf) then M.run(buf) end
        end)
    else
        run_syntax(buf)
    end
end

local function debounce(timers_of, buf, wait, action)
    timers_of[buf] = timers_of[buf] or vim.uv.new_timer()
    timers_of[buf]:stop()
    timers_of[buf]:start(wait, 0, vim.schedule_wrap(function()
        if vim.api.nvim_buf_is_valid(buf) then action(buf) end
    end))
end

local function schedule(buf)
    if not M.enabled then return end
    debounce(fast_timers, buf, 100, M.quick)
    debounce(timers, buf, delay, function(target) M.run(target) end)
end

function M.toggle()
    M.enabled = not M.enabled
    vim.diagnostic.enable(M.enabled)
    if M.enabled then
        M.quick(vim.api.nvim_get_current_buf())
        M.run(nil, true)
    else
        vim.diagnostic.reset(namespace)
        vim.diagnostic.reset(fast_namespace)
    end
    vim.cmd('redraw')
    vim.api.nvim_echo({ { 'Diagnostics ' .. (M.enabled and 'ON' or 'OFF'), M.enabled and 'DiagnosticOk' or 'WarningMsg' } }, true, {})
end

function M.setup()
    vim.diagnostic.enable(false)
    project.on_index(function() -- The headers of the project are listed: the includes that were not found are checked again
        if not M.enabled then return end
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) then
                failed = {}
                M.run(buf, true)
            end
        end
    end)
    vim.diagnostic.config({
        virtual_text = { prefix = '●', spacing = 2 },
        underline = true,
        severity_sort = true,
        update_in_insert = true,
        signs = {
            text = { [severity.ERROR] = '✖', [severity.WARN] = '▲', [severity.INFO] = '●', [severity.HINT] = '·' },
            linehl = {
                [severity.ERROR] = 'DiagLineError', [severity.WARN] = 'DiagLineWarn',
                [severity.INFO] = 'DiagLineInfo', [severity.HINT] = 'DiagLineHint',
            },
        },
    })
    set_highlights()

    local group = vim.api.nvim_create_augroup('Checks', { clear = true })
    vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = set_highlights })
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = group,
        callback = function(args) schedule(args.buf) end,
    })
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, { -- The precompiled header of the includes, in advance
        group = group,
        callback = function(args)
            vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(args.buf) then M.prewarm(args.buf) end
            end, 800)
        end,
    })
end

return M
