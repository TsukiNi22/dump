-- Index of the symbols (functions, types, variables, members, macros) of the current C / C++ buffer and of its
-- #include files, with their signature and the comment written above them (treesitter, no language server)
local project = require('matching.project')
local M = {}

local kinds_with_body = {
    class_specifier = true, struct_specifier = true, union_specifier = true, enum_specifier = true,
}
local containers = { -- Nodes that only hold declarations
    translation_unit = true, declaration_list = true, linkage_specification = true,
    preproc_ifdef = true, preproc_if = true, preproc_else = true, preproc_elif = true, template_declaration = true,
}
local declarator_wrappers = {
    function_declarator = true, pointer_declarator = true, reference_declarator = true, array_declarator = true,
    init_declarator = true, parenthesized_declarator = true,
}
local name_nodes = {
    identifier = true, field_identifier = true, type_identifier = true, operator_name = true, destructor_name = true,
}

local file_cache = {}   -- path -> { mtime, entries, includes }
local buffer_cache = {} -- buffer -> { tick, entries, includes }
local max_file_size = 400 * 1024

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function text_of(node, source) return vim.treesitter.get_node_text(node, source) end

local function squash(text) return (text:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')) end

local function clean_comment(text)
    local lines = {}
    for line in (text .. '\n'):gmatch('(.-)\n') do
        line = line:gsub('^%s*/%*+!?<?', ''):gsub('%*+/%s*$', ''):gsub('^%s*%*+ ?', ''):gsub('^%s*//[/!]?<? ?', '')
        table.insert(lines, (line:gsub('%s+$', '')))
    end
    return vim.trim(table.concat(lines, '\n'))
end

-- The comments written right above a node
local function doc_of(node, source)
    local lines = {}
    local expected_row = node:start()
    local previous = node:prev_sibling()
    while previous and previous:type() == 'comment' do
        local start_row, _, end_row = previous:range()
        if end_row < expected_row - 1 then break end
        table.insert(lines, 1, clean_comment(text_of(previous, source)))
        expected_row = start_row
        previous = previous:prev_sibling()
    end
    return table.concat(lines, '\n')
end

local function declarator_name(node, source)
    while node do
        local type = node:type()
        if name_nodes[type] then return text_of(node, source) end
        if type == 'qualified_identifier' or type == 'template_function' then
            node = node:field('name')[1]
        elseif declarator_wrappers[type] then
            node = node:field('declarator')[1] or node:named_child(0)
        else
            return nil
        end
    end
end

local function is_function_declarator(node)
    while node do
        local type = node:type()
        if type == 'function_declarator' then return true end
        if not declarator_wrappers[type] then return false end
        node = node:field('declarator')[1] or node:named_child(0)
    end
    return false
end

local function signature_of(node, source)
    local text = text_of(node, source)
    text = text:match('^(.-)%s*{') or text -- Definition: up to the body
    text = text:gsub(';%s*$', '')
    text = squash(text)
    if #text > 180 then text = text:sub(1, 177) .. '...' end
    return text
end

--------------------------------------------------------------------------------
-- Parsing of a text
--------------------------------------------------------------------------------
local current_namespace = nil -- Innermost namespace being walked

local function add(out, entry, node, source, doc_node)
    if not entry.name:match('^[%a_][%w_]*$') then return end -- Operators, specializations, destructors...
    entry.doc = doc_of(doc_node or node, source)
    entry.ns = current_namespace
    entry.line = node:start() + 1
    table.insert(out, entry)
end

local walk

local function handle(node, source, out, owner, includes, doc_node)
    local type = node:type()

    if type == 'function_definition' then
        local name = declarator_name(node:field('declarator')[1], source)
        if name then
            add(out, { name = name, kind = owner and 'method' or 'function', owner = owner,
                signature = signature_of(node, source) }, node, source, doc_node)
        end

    elseif type == 'declaration' or type == 'field_declaration' then
        for _, declarator in ipairs(node:field('declarator')) do
            local name = declarator_name(declarator, source)
            if name then
                local is_function = is_function_declarator(declarator)
                local kind = is_function and (owner and 'method' or 'function') or (owner and 'member' or 'variable')
                add(out, { name = name, kind = kind, owner = owner, signature = signature_of(node, source) },
                    node, source, doc_node)
            end
        end
        local type_node = node:field('type')[1] -- struct Foo { ... } declared inside a declaration
        if type_node and kinds_with_body[type_node:type()] then handle(type_node, source, out, owner, includes) end

    elseif kinds_with_body[type] then
        local name_node = node:field('name')[1]
        local name = name_node and text_of(name_node, source)
        local body = node:field('body')[1]
        if name then
            add(out, { name = name, kind = 'type', owner = owner, signature = type:gsub('_specifier', '') .. ' ' .. name },
                node, source, doc_node)
        end
        if body then
            if type == 'enum_specifier' then
                for enumerator in body:iter_children() do
                    local enum_name = enumerator:type() == 'enumerator' and enumerator:field('name')[1]
                    if enum_name then
                        add(out, { name = text_of(enum_name, source), kind = 'constant', owner = name,
                            signature = squash(text_of(enumerator, source)) }, enumerator, source)
                    end
                end
            else
                walk(body, source, out, name or owner, includes)
            end
        end

    elseif type == 'type_definition' then
        for _, declarator in ipairs(node:field('declarator')) do
            local name = declarator_name(declarator, source)
            if name then
                add(out, { name = name, kind = 'type', signature = signature_of(node, source) }, node, source, doc_node)
            end
        end
        local type_node = node:field('type')[1]
        if type_node and kinds_with_body[type_node:type()] then handle(type_node, source, out, owner, includes) end

    elseif type == 'alias_declaration' then
        local name = node:field('name')[1]
        if name then
            add(out, { name = text_of(name, source), kind = 'type', signature = signature_of(node, source) },
                node, source, doc_node)
        end

    elseif type == 'preproc_def' or type == 'preproc_function_def' then
        local name = node:field('name')[1]
        if name then
            local params = node:field('parameters')[1]
            local label = '#define ' .. text_of(name, source) .. (params and text_of(params, source) or '')
            add(out, { name = text_of(name, source), kind = 'macro', signature = label }, node, source, doc_node)
        end

    elseif type == 'preproc_include' then
        local path = node:field('path')[1]
        if path then
            local text = text_of(path, source)
            table.insert(includes, { open = text:sub(1, 1), path = text:sub(2, -2) })
        end

    elseif type == 'namespace_definition' then
        local name_node = node:field('name')[1]
        local name = name_node and text_of(name_node, source)
        local body = node:field('body')[1]
        local outer = current_namespace
        if name then
            for part in name:gmatch('[%w_]+') do -- namespace a::b { ... } holds a then b
                add(out, { name = part, kind = 'namespace', signature = 'namespace ' .. part }, node, source, doc_node)
                current_namespace = part
            end
        end
        if body then walk(body, source, out, owner, includes) end
        current_namespace = outer

    elseif containers[type] then
        walk(node, source, out, owner, includes, type == 'template_declaration' and node or nil)
    end
end

walk = function(node, source, out, owner, includes, doc_node)
    for child in node:iter_children() do
        if child:named() then handle(child, source, out, owner, includes, doc_node) end
    end
end

-- text -> entries, includes
local function parse(text, lang)
    local ok, parser = pcall(vim.treesitter.get_string_parser, text, lang)
    if not ok then return {}, {} end
    local trees = parser:parse()
    if not trees or not trees[1] then return {}, {} end

    local out, includes = {}, {}
    local walked, err = pcall(walk, trees[1]:root(), text, out, nil, includes)
    if not walked then M.last_error = err end
    return out, includes
end

--------------------------------------------------------------------------------
-- Include paths
--------------------------------------------------------------------------------
function M.include_dirs(open, buf)
    local cwd = vim.fn.getcwd()
    local file_dir = buf and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':p:h') or vim.fn.expand('%:p:h')
    local dirs = {}
    local project_dirs = project.options(vim.fn.fnamemodify(file_dir .. '/x', ':p'), {}, false)
    if open == '"' then vim.list_extend(dirs, { file_dir, cwd, cwd .. '/include', cwd .. '/src' })
    else vim.list_extend(dirs, { cwd .. '/include' }) end
    for index = 2, #project_dirs, 2 do -- Folders of the compile database / the include, src... above the file
        local dir = project_dirs[index]
        -- <...>: only the include folders, not every folder above the file
        if project_dirs[index - 1]:match('^%-[Ii]') and (open == '"' or dir:match('/inc[a-z]*$')) then table.insert(dirs, dir) end
    end
    vim.list_extend(dirs, { '/usr/local/include', '/usr/include' })
    vim.list_extend(dirs, vim.fn.glob('/usr/include/c++/*', false, true)) -- C++ standard headers
    return dirs
end

local function resolve(include, buf)
    for _, dir in ipairs(M.include_dirs(include.open, buf)) do
        local path = dir .. '/' .. include.path
        local stat = vim.uv.fs_stat(path)
        if stat and stat.type == 'file' then return path, stat, dir:find('^/usr') ~= nil end
    end
    local file = buf and vim.api.nvim_buf_get_name(buf) or ''
    local dir = file ~= '' and project.find_include(file, include.path) -- Not in the usual folders: searched in the project
    if dir then
        local path = dir .. '/' .. include.path
        return path, vim.uv.fs_stat(path), false
    end
end

local function file_entries(path, stat, lang)
    local cached = file_cache[path]
    if cached and cached.mtime == stat.mtime.sec then return cached end
    local file = io.open(path, 'r')
    if not file then return { entries = {}, includes = {}, mtime = 0 } end
    local text = file:read('*a')
    file:close()
    local entries, includes = parse(text, lang)
    for _, entry in ipairs(entries) do entry.file = path end
    cached = { mtime = stat.mtime.sec, entries = entries, includes = includes }
    file_cache[path] = cached
    return cached
end

--------------------------------------------------------------------------------
-- Entries of a buffer (itself + its includes)
--------------------------------------------------------------------------------
local function language_of(buf)
    local filetype = vim.bo[buf].filetype
    if filetype == 'c' or filetype == 'cpp' then return filetype end
end

function M.supported(buf) return language_of(buf or 0) ~= nil end

local follow_cache = {} -- buffer -> { sig, time, extra }: entries of the includes, resolved again only every few seconds

local function rebuild(buf, lang)
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    local entries, includes = parse(text, lang)
    local name = vim.api.nvim_buf_get_name(buf)
    for _, entry in ipairs(entries) do entry.file = name end

    local signature = {}
    for _, include in ipairs(includes) do table.insert(signature, include.open .. include.path) end
    signature = table.concat(signature, '\n')

    local cached = follow_cache[buf]
    local extra
    if cached and cached.signature == signature and os.time() - cached.time < 3 then
        extra = cached.extra -- Same #include lines: no stat / read of the headers again
    else
        extra = {}
        local visited, files = { [name] = true }, 0
        local function follow(list, depth)
            for _, include in ipairs(list) do
                local path, stat, system = resolve(include, buf)
                -- System headers: one level, small, and without their private names (_M_...)
                if path and stat and not visited[path] and stat.size < max_file_size and files < 40
                    and (not system or depth == 1) then
                    visited[path] = true
                    files = files + 1
                    local file = file_entries(path, stat, lang)
                    for _, entry in ipairs(file.entries) do
                        if not (system and entry.name:sub(1, 1) == '_') then table.insert(extra, entry) end
                    end
                    if depth < 3 then follow(file.includes, depth + 1) end
                end
            end
        end
        follow(includes, 1)
        follow_cache[buf] = { signature = signature, time = os.time(), extra = extra }
    end

    local all = vim.list_extend({}, entries)
    vim.list_extend(all, extra)
    buffer_cache[buf] = { tick = tick, all = all }
    return all
end

-- The buffer is parsed again only once the typing pauses (the previous result is used meanwhile): no parse per key
function M.entries(buf)
    buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
    local lang = language_of(buf)
    if not lang then return {} end

    local cached = buffer_cache[buf]
    if not cached then return rebuild(buf, lang) end
    if cached.tick == vim.api.nvim_buf_get_changedtick(buf) then return cached.all end

    if not cached.pending then
        cached.pending = true
        vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(buf) then rebuild(buf, lang) end
        end, 150)
    end
    return cached.all
end

-- Entry by name (functions, types, macros...) for the help under the mouse
function M.lookup(buf, name)
    local best
    for _, entry in ipairs(M.entries(buf)) do
        if entry.name == name then
            if entry.doc ~= '' and (not best or best.doc == '') then best = entry end
            best = best or entry
        end
    end
    return best
end

return M
