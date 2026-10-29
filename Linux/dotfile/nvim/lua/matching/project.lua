-- Where the headers of a C / C++ file are: the compile database (CMake, bear...), the usual folders (include, src...)
-- of the folders above the file, and as last resort a search of the file itself in the project, with or without CMake
local M = {}

local markers = { '.git', 'compile_commands.json', 'CMakeLists.txt', 'Makefile', 'meson.build', 'Cargo.toml' }
local sub_dirs = { '', 'include', 'includes', 'inc', 'src', 'source', 'sources', 'headers', 'lib' }
local build_dirs = { '.', 'build', 'Build', 'build-debug', 'build-release', 'cmake-build-debug', 'cmake-build-release', 'out', '.build', 'bin' }

local db_cache = {}     -- compile_commands.json -> { mtime, flags, by_file }

local function is_file(path)
    local stat = vim.uv.fs_stat(path)
    return stat ~= nil and stat.type == 'file'
end

local function is_dir(path)
    local stat = vim.uv.fs_stat(path)
    return stat ~= nil and stat.type == 'directory'
end

-- Folders from the one of the file up to the root of the project
local function ancestors(file)
    local list = {}
    for dir in vim.fs.parents(vim.fs.normalize(file)) do
        table.insert(list, dir)
        if #list >= 12 or dir == '/' or dir == vim.uv.os_homedir() then break end
    end
    return list
end

-- Root of the project: the highest folder with a .git, else with a build file, else a few levels above the file
function M.root(file)
    local list = ancestors(file)
    for _, wanted in ipairs({ { '.git' }, { 'compile_commands.json', 'CMakeLists.txt', 'Makefile', 'meson.build', 'Cargo.toml' } }) do
        local found
        for _, dir in ipairs(list) do
            for _, marker in ipairs(wanted) do
                if vim.uv.fs_stat(dir .. '/' .. marker) then found = dir end
            end
        end
        if found then return found end
    end
    return list[math.min(#list, 3)] or vim.fn.getcwd()
end

--------------------------------------------------------------------------------
-- Compile database
--------------------------------------------------------------------------------
local function split_command(command)
    local words = {}
    for word in command:gmatch('%S+') do table.insert(words, word) end
    return words
end

-- -I / -isystem / -D / -std of one compile command (relative paths are relative to its directory)
local function flags_of(entry, flags)
    local words = entry.arguments or split_command(entry.command or '')
    local index = 1
    while index <= #words do
        local word = words[index]
        local kind, value = word:match('^(%-I)(.+)$')
        if not kind then kind, value = word:match('^(%-isystem)(.+)$') end
        if not kind and (word == '-I' or word == '-isystem' or word == '-iquote') then
            kind, value = word, words[index + 1]
            index = index + 1
        end
        if kind and value then
            if value:sub(1, 1) ~= '/' then value = (entry.directory or '') .. '/' .. value end
            table.insert(flags, kind == '-iquote' and '-I' or kind)
            table.insert(flags, vim.fs.normalize(value))
        elseif word:match('^%-D') or word:match('^%-std=') then
            table.insert(flags, word)
        end
        index = index + 1
    end
end

local function load_db(path)
    local stat = vim.uv.fs_stat(path)
    if not stat then return end
    local cached = db_cache[path]
    if cached and cached.mtime == stat.mtime.sec then return cached end
    local file = io.open(path, 'r')
    if not file then return end
    local ok, entries = pcall(vim.json.decode, file:read('*a'))
    file:close()
    if not ok or type(entries) ~= 'table' then return end
    cached = { mtime = stat.mtime.sec, all = {}, by_file = {}, by_dir = {} }
    local seen = {}
    for _, entry in ipairs(entries) do
        local name = entry.file and (entry.file:sub(1, 1) == '/' and entry.file or (entry.directory or '') .. '/' .. entry.file)
        if name then
            local flags = {}
            flags_of(entry, flags)
            name = vim.fs.normalize(name)
            cached.by_file[name] = flags
            cached.by_dir[vim.fs.dirname(name)] = cached.by_dir[vim.fs.dirname(name)] or flags
            for index = 1, #flags - 1, 2 do -- Only the pairs -I dir, -isystem dir
                local key = flags[index] .. ' ' .. flags[index + 1]
                if flags[index]:match('^%-[Ii]') and not seen[key] then
                    seen[key] = true
                    table.insert(cached.all, flags[index])
                    table.insert(cached.all, flags[index + 1])
                end
            end
        end
    end
    db_cache[path] = cached
    return cached
end

-- compile_commands.json of the project (in the root or in the usual build folders, also above the file)
local db_path_cache = {} -- folder of the file -> { time, path | false }

function M.compile_db(file)
    local folder = vim.fs.dirname(file)
    local cached = db_path_cache[folder]
    if cached and os.time() - cached.time < 5 then return cached.path or nil end
    local path = M.find_compile_db(file)
    db_path_cache[folder] = { time = os.time(), path = path or false }
    return path
end

function M.find_compile_db(file)
    local roots = ancestors(file)
    for _, root in ipairs(roots) do
        for _, build in ipairs(build_dirs) do
            local path = root .. '/' .. build .. '/compile_commands.json'
            if is_file(path) then return path end
        end
        for _, build in ipairs(vim.fn.glob(root .. '/{build,cmake-build}*/compile_commands.json', false, true)) do
            return build
        end
        if vim.uv.fs_stat(root .. '/.git') then break end
    end
end

-- Flags of the file (exact entry, else the same folder, else every include folder of the project for a header)
local function db_flags(file)
    local path = M.compile_db(file)
    local db = path and load_db(path)
    if not db then return {} end
    file = vim.fs.normalize(file)
    if db.by_file[file] then return db.by_file[file] end
    local dir = vim.fs.dirname(file)
    if db.by_dir[dir] then return db.by_dir[dir] end
    return db.all
end

--------------------------------------------------------------------------------
-- Without compile database
--------------------------------------------------------------------------------
-- Candidates: include, src... of every folder above the file (nearest first)
local function guessed_dirs(file)
    local dirs = {}
    for _, dir in ipairs(ancestors(file)) do
        for _, sub in ipairs(sub_dirs) do
            local path = sub == '' and dir or (dir .. '/' .. sub)
            if (sub == '' or is_dir(path)) and not vim.tbl_contains(dirs, path) then table.insert(dirs, path) end
        end
        if vim.uv.fs_stat(dir .. '/.git') then break end
    end
    return dirs
end

-- Headers of the project, listed once in the background (rg, else git, else find): basename -> paths. A lookup never
-- waits for it: before the list is ready nothing is found, and `on_index` tells when to check again
local indexes = {} -- root -> { map, time, building }
local listeners = {}

function M.on_index(callback) table.insert(listeners, callback) end

local function index_command(root)
    local globs = '*.{h,hpp,hh,hxx,H,tpp,ipp,inc}'
    if vim.fn.executable('rg') == 1 then return { 'rg', '--files', '--no-messages', '-g', globs, root } end
    if vim.uv.fs_stat(root .. '/.git') and vim.fn.executable('git') == 1 then
        return { 'git', '-C', root, 'ls-files', '--cached', '--others', '--exclude-standard', '*.h', '*.hpp', '*.hh', '*.hxx', '*.tpp', '*.ipp' }
    end
    return { 'find', root, '(', '-name', '.git', '-o', '-name', 'node_modules', '-o', '-name', 'build', ')', '-prune', '-o',
        '-type', 'f', '(', '-name', '*.h', '-o', '-name', '*.hpp', '-o', '-name', '*.hh', '-o', '-name', '*.hxx', ')', '-print' }
end

local function build_index(root)
    local index = indexes[root] or { map = {}, time = 0 }
    indexes[root] = index
    if index.building then return end
    index.building = true
    vim.system(index_command(root), { text = true }, function(result)
        vim.schedule(function()
            local map = {}
            for path in (result.stdout or ''):gmatch('[^\n]+') do
                if path:sub(1, 1) ~= '/' then path = root .. '/' .. path end
                if not path:find('/build[^/]*/') and not path:find('/%.[^/]+/') then -- No build / hidden folders
                    local name = path:match('[^/]+$')
                    map[name] = map[name] or {}
                    table.insert(map[name], path)
                end
            end
            index.map, index.time, index.building, index.ready = map, os.time(), nil, true
            for _, callback in ipairs(listeners) do callback() end
        end)
    end)
end

function M.prepare(file) -- At the opening of a file: the list is ready before the first check
    local root = M.root(file)
    if not indexes[root] then build_index(root) end
end

-- Folder to give to -I so that `#include "<include>"` is found
local function search_include(root, include)
    local index = indexes[root]
    if not index then build_index(root) return end
    local name = include:match('[^/]+$')
    for _, path in ipairs(index.map[name] or {}) do
        if path:sub(-#include - 1) == '/' .. include then return path:sub(1, #path - #include - 1) end
    end
    if not index.building and os.time() - index.time > 20 then build_index(root) end -- A new header may exist now
end

-- Folder where the file of an #include is found, nil when it is not in the project
function M.find_include(file, include)
    for _, dir in ipairs(guessed_dirs(file)) do
        if is_file(dir .. '/' .. include) then return dir end
    end
    return search_include(M.root(file), include)
end

-- Every folder to search the headers of a file in (the project only, the system ones are known by the compiler)
function M.dirs(file, includes)
    local dirs = guessed_dirs(file)
    for _, include in ipairs(includes or {}) do
        local found = false
        for _, dir in ipairs(dirs) do
            if is_file(dir .. '/' .. include) then found = true break end
        end
        if not found then
            local dir = search_include(M.root(file), include)
            if dir and not vim.tbl_contains(dirs, dir) then table.insert(dirs, 1, dir) end
        end
    end
    return dirs
end

-- Compiler options of the file: the ones of the compile database, else the folders found
local options_cache = {} -- key -> { time, options }

function M.options(file, includes, cpp)
    local key = file .. '\0' .. table.concat(includes or {}, '\0') .. (cpp and 'c' or '')
    local cached = options_cache[key]
    if cached and os.time() - cached.time < 3 then return cached.options end -- Called at each check: not recomputed each time
    local options = {}
    local flags = db_flags(file)
    local has_std = false
    for _, flag in ipairs(flags) do
        if flag:match('^%-std=') then has_std = true end
    end
    vim.list_extend(options, flags)
    for _, dir in ipairs(M.dirs(file, includes)) do vim.list_extend(options, { '-I', dir }) end
    if cpp and not has_std then table.insert(options, '-std=c++20') end
    options_cache[key] = { time = os.time(), options = options }
    return options
end

return M
