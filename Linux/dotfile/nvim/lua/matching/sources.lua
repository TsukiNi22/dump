-- Completion sources that work without any language server: keywords, #directives, #include paths, symbols and
-- members (with their signature and comment) of the file and of its includes, words of the file
-- They bypass the matcher of cmp: a word is accepted when it holds the typed letters in order, or when it is close
-- to the typed word for c2dmp-hsm (inversions allowed: '#nilde' finds 'include'), and c2dmp-hsm ranks them
local M = {}

local cmp = require('cmp')
local kinds = cmp.lsp.CompletionItemKind
local index = require('matching.index')
local c2dmp = require('matching.c2dmp')

local max_distance = 1.5 -- c2dmp-hsm: 'nilde' -> 'include' is 1.43, 'xyz' -> 'include' is 7

--------------------------------------------------------------------------------
-- Matching
--------------------------------------------------------------------------------
local function subsequence(typed, word)
    local position = 1
    for char in typed:gmatch('.') do
        local found = word:find(char, position, true)
        if not found then return false end
        position = found + 1
    end
    return true
end

local function near(typed, word)
    if typed == '' then return true end
    local lower_typed, lower_word = typed:lower(), word:lower()
    if lower_word:find(lower_typed, 1, true) or subsequence(lower_typed, lower_word) then return true end
    return c2dmp.available and #typed >= 4 and c2dmp.distance(lower_typed, lower_word) <= max_distance
end

-- Items near the typed word, whatever the cmp matcher thinks (filterText = typed), ranked by c2dmp-hsm afterwards
local function reply(callback, items, typed)
    local result = {}
    for _, item in ipairs(items) do
        if near(typed, item.match or item.label) then
            local copy = {}
            for key, value in pairs(item) do copy[key] = value end
            if typed ~= '' then copy.filterText = typed end
            table.insert(result, copy)
        end
    end
    callback({ items = result, isIncomplete = true }) -- Asked again at every key
end

local function typed_word(context)
    local filetype = vim.bo.filetype
    if filetype == 'css' or filetype == 'scss' or filetype == 'less' or filetype == 'html' then -- font-size, data-id
        return context.cursor_before_line:match('[%w_%-]*$') or ''
    end
    return context.cursor_before_line:match('[%w_]*$') or ''
end

local function after_member_access(before) -- 'obj.', 'ptr->', 'Type::'
    return before:match('%.[%w_]*$') or before:match('%->[%w_]*$') or before:match('::[%w_]*$')
end

local function documentation(entry) return { kind = 'markdown', value = require('matching.doc').markdown(entry) } end

local entry_kinds = {
    ['function'] = kinds.Function, method = kinds.Method, type = kinds.Class, variable = kinds.Variable,
    member = kinds.Field, macro = kinds.Constant, constant = kinds.EnumMember, namespace = kinds.Module,
}

local function item_of(entry)
    return {
        label = entry.name,
        kind = entry_kinds[entry.kind] or kinds.Text,
        documentation = documentation(entry),
    }
end

--------------------------------------------------------------------------------
-- Keywords and #directives
--------------------------------------------------------------------------------
local c_words = [[auto break case char const continue default do double else enum extern float for goto if inline int
    long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while
    bool true false NULL size_t uint8_t uint16_t uint32_t uint64_t int8_t int16_t int32_t int64_t]]

local cpp_words = c_words .. [[ alignas alignof and asm bitand bitor catch class compl concept consteval constexpr
    constinit const_cast co_await co_return co_yield decltype delete dynamic_cast explicit export final friend mutable
    namespace new noexcept not nullptr operator or override private protected public reinterpret_cast requires
    static_assert static_cast template this thread_local throw try typeid typename using virtual xor
    std string vector map unordered_map set array optional variant string_view unique_ptr shared_ptr make_unique
    make_shared move forward cout cerr endl]]

local lists = {
    c = c_words,
    cpp = cpp_words,
    python = [[False None True and as assert async await break class continue def del elif else except finally for from
        global if import in is lambda nonlocal not or pass raise return try while with yield print len range str int
        float list dict set tuple open isinstance enumerate zip self]],
    lua = [[and break do else elseif end false for function goto if in local nil not or repeat return then true until
        while require pairs ipairs print table string vim]],
    sh = [[if then else elif fi for while until do done case esac function in select time return exit local export
        readonly declare unset shift echo source set]],
    cmake = [[if elseif else endif foreach endforeach while endwhile function endfunction macro endmacro set list
        add_executable add_library target_link_libraries target_include_directories find_package include
        cmake_minimum_required project option message return]],
}
lists.rust = [[as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move
    mut pub ref return self Self static struct super trait true type unsafe use where while Option Some None Result Ok Err
    Vec String Box Rc Arc println vec format]]
lists.javascript = [[async await break case catch class const continue default delete do else export extends false finally for
    from function if import in instanceof let new null of return static super switch this throw true try typeof undefined var
    void while yield console document window Promise Array Object JSON Math Map Set]]
lists.typescript = lists.javascript .. [[ interface type enum implements namespace declare readonly private protected public abstract
    keyof infer unknown never any string number boolean Record Partial Pick Omit]]
lists.html = [[div span p a img ul ol li table tr td th form input button label select option textarea h1 h2 h3 h4 header footer
    main nav section article aside script style link meta title head body html class id href src alt type name value]]
lists.css = [[display position flex grid margin padding border background color font-size font-family font-weight width height
    min-width max-width min-height max-height overflow opacity transition transform animation z-index top right bottom left
    justify-content align-items gap box-sizing cursor content var calc none auto inherit relative absolute fixed sticky center]]
lists.zig = [[align allowzero and anyerror anytype asm async await break catch comptime const continue defer else enum errdefer error
    export extern false fn for if inline noalias null opaque or orelse packed pub resume return struct suspend switch test true
    try union unreachable usingnamespace var volatile while std @import @as @intCast]]
lists.go = [[break case chan const continue default defer else fallthrough for func go goto if import interface map package range
    return select struct switch type var nil true false fmt error string int bool byte rune make len append]]
lists.java = [[abstract boolean break byte case catch char class const continue default do double else enum extends final finally
    float for if implements import instanceof int interface long new null package private protected public return short static
    super switch this throw throws true false try void volatile while String System List Map]]
lists.php = [[abstract and array as break case catch class clone const continue default do echo else elseif empty extends final
    finally fn for foreach function global if implements include interface isset namespace new null private protected public
    require return static switch this throw trait try use var while]]
lists.sql = [[SELECT FROM WHERE INSERT INTO VALUES UPDATE SET DELETE CREATE TABLE ALTER DROP INDEX JOIN INNER LEFT RIGHT OUTER ON
    GROUP BY ORDER HAVING LIMIT OFFSET DISTINCT AS AND OR NOT NULL IN LIKE BETWEEN EXISTS UNION PRIMARY KEY FOREIGN REFERENCES]]
lists.asm = [[mov add sub mul imul div idiv inc dec neg cmp test jmp je jne jg jge jl jle ja jb call ret push pop lea xor and or
    not shl shr sar nop syscall int rax rbx rcx rdx rsi rdi rbp rsp r8 r9 r10 r11 r12 r13 r14 r15 eax ebx ecx edx esi edi
    section global extern db dw dd dq equ resb resw resd resq times byte word dword qword]]
lists.nasm = lists.asm
lists.scss = lists.css
lists.javascriptreact = lists.javascript
lists.typescriptreact = lists.typescript
lists.bash = lists.sh
lists.zsh = lists.sh

local directives = 'define elif else endif error if ifdef ifndef include line pragma undef warning'

local word_items = {}
local function items_of(key, words, kind)
    if not word_items[key] then
        local items = {}
        for word in words:gmatch('%S+') do table.insert(items, { label = word, kind = kind }) end
        word_items[key] = items
    end
    return word_items[key]
end

local keywords = {}
function keywords:is_available() return lists[vim.bo.filetype] ~= nil end
function keywords:get_trigger_characters() return { '#' } end
function keywords:complete(params, callback)
    local before = params.context.cursor_before_line
    local filetype = vim.bo.filetype
    local directive = before:match('^%s*#%s*(%a*)$')
    if directive and (filetype == 'c' or filetype == 'cpp') then
        return reply(callback, items_of('directives', directives, kinds.Keyword), directive)
    end
    if after_member_access(before) then return callback({}) end
    reply(callback, items_of(filetype, lists[filetype], kinds.Keyword), typed_word(params.context))
end

--------------------------------------------------------------------------------
-- Very common things ([std]): main, control structures, usual includes and calls (matching/common.lua)
--------------------------------------------------------------------------------
local common = {}
function common:is_available() return #require('matching.common').items(vim.bo.filetype, 'top') > 0 end
function common:get_trigger_characters() return { '#' } end
function common:complete(params, callback)
    local buf = params.context.bufnr
    local before = params.context.cursor_before_line
    local filetype = vim.bo[buf].filetype
    local catalog = require('matching.common')

    local name = vim.api.nvim_buf_get_name(buf)
    local file = { name = name }
    local is_c = filetype == 'c' or filetype == 'cpp'

    local contexts = {} -- { { context, typed } }: a line that only holds a word has two readings
    local directive = before:match('^%s*#%s*(%a*)$')
    if directive and is_c then
        contexts = { { 'hash', directive } }
    elseif after_member_access(before) then
        return callback({})
    else
        local position = vim.api.nvim_win_get_cursor(0)
        local context = catalog.in_body(buf, position[1] - 1, position[2]) and 'body' or 'top'
        contexts = { { context, typed_word(params.context) } }
        local bare = before:match('^%s*([%a_]*)$')
        if is_c and bare and #bare >= 2 then table.insert(contexts, { 'line', bare }) end -- 'def' -> '#define'
    end

    local items = {}
    for _, reading in ipairs(contexts) do
        for _, entry in ipairs(catalog.items(filetype, reading[1], file)) do
            table.insert(items, {
                label = entry.label, match = entry.match, strict = entry.strict, kind = kinds[entry.kind] or kinds.Snippet,
                insertText = entry.snippet, insertTextFormat = 2, -- 2: snippet (the fields are jumped with Tab)
                documentation = { kind = 'markdown', value = '**Common**\n\n' .. entry.doc },
                data = { group = entry.group, rank = entry.rank, special = entry.special },
                typed = reading[2],
            })
        end
    end
    -- Each reading filters with its own typed word
    local result = {}
    for _, item in ipairs(items) do
        -- A line that only holds a word ('def'): the exact letters only, so that '#define' does not appear for every word
        local found = item.strict and (item.match or item.label):lower():find(item.typed:lower(), 1, true)
            or (not item.strict and near(item.typed, item.match or item.label))
        if found then
            item.filterText = item.typed ~= '' and item.typed or nil
            item.typed, item.strict = nil, nil
            table.insert(result, item)
        end
    end
    callback({ items = result, isIncomplete = true })
end

--------------------------------------------------------------------------------
-- #include "..." / <...> : headers and folders of the include paths
--------------------------------------------------------------------------------
local headers = { h = true, hpp = true, hh = true, hxx = true, tcc = true, inc = true, ipp = true }

local include = {}
function include:is_available() return vim.bo.filetype == 'c' or vim.bo.filetype == 'cpp' end
function include:get_trigger_characters() return { '"', '<', '/' } end
function include:get_keyword_pattern() return [[\%([^/\\:\*?<>'"`\|]\)*]] end
function include:complete(params, callback)
    local open, path = params.context.cursor_before_line:match('^%s*#%s*include%s*([<"])([^<>"]*)$')
    if not open then return callback({}) end

    local sub = path:match('^(.*/)') or ''
    local typed = path:sub(#sub + 1)
    local seen, items = {}, {}
    for _, base in ipairs(index.include_dirs(open, params.context.bufnr)) do
        local handle = vim.uv.fs_scandir(base .. '/' .. sub)
        while handle do
            local name, type = vim.uv.fs_scandir_next(handle)
            if not name then break end
            if type == 'link' then
                local stat = vim.uv.fs_stat(base .. '/' .. sub .. name)
                type = stat and stat.type or 'file'
            end
            local extension = name:match('%.(%w+)$')
            local is_dir = type == 'directory'
            if name:sub(1, 1) ~= '.' and (is_dir or extension == nil or headers[extension]) then
                local label = is_dir and (name .. '/') or name
                if not seen[label] then
                    seen[label] = true
                    table.insert(items, { label = label, kind = is_dir and kinds.Folder or kinds.File })
                end
            end
        end
    end
    reply(callback, items, typed)
end

--------------------------------------------------------------------------------
-- Symbols: C / C++ -> index of the file and of its includes, the other languages -> identifiers (treesitter)
--------------------------------------------------------------------------------
local identifiers = { identifier = true, type_identifier = true, field_identifier = true, namespace_identifier = true }
local generic_cache = {}

local function generic_symbols(buf)
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local cached = generic_cache[buf]
    if cached and cached.tick == tick then return cached.items end

    local items = {}
    local ok, parser = pcall(vim.treesitter.get_parser, buf)
    local trees = ok and parser and parser:parse()
    if trees and trees[1] then
        local found, stack, count = {}, { trees[1]:root() }, 0
        while #stack > 0 and count < 20000 do
            local node = table.remove(stack)
            count = count + 1
            if identifiers[node:type()] then
                local text = vim.treesitter.get_node_text(node, buf)
                if #text > 1 and not found[text] then
                    found[text] = true
                    table.insert(items, { label = text, kind = kinds.Variable })
                end
            end
            for child in node:iter_children() do table.insert(stack, child) end
        end
    end
    generic_cache[buf] = { tick = tick, items = items }
    return items
end

local symbols = {}
function symbols:is_available() return lists[vim.bo.filetype] ~= nil or index.supported(0) end
function symbols:complete(params, callback)
    local buf = params.context.bufnr
    local typed = typed_word(params.context)
    if after_member_access(params.context.cursor_before_line) then return callback({}) end

    local items = {}
    if index.supported(buf) then
        local seen = {}
        for _, entry in ipairs(index.entries(buf)) do
            local scoped = entry.owner and entry.kind ~= 'constant'
            if not scoped and entry.name ~= typed and not seen[entry.name] then
                seen[entry.name] = true
                table.insert(items, item_of(entry))
            end
        end
    else
        for _, item in ipairs(generic_symbols(buf)) do
            if item.label ~= typed then table.insert(items, item) end
        end
    end
    reply(callback, items, typed)
end

--------------------------------------------------------------------------------
-- Members: after 'obj.', 'ptr->' and 'Type::' (the type of 'obj' is looked for in the file)
--------------------------------------------------------------------------------
local function type_of_variable(buf, name, line)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, line, false)
    for row = #lines, 1, -1 do
        local text = lines[row]
        local found = text:match('([%a_][%w_:]*)%s*%b<>%s*[%*&]*%s*' .. name .. '%f[^%w_]')
            or text:match('([%a_][%w_:]*)%s*[%*&]+%s*' .. name .. '%f[^%w_]')
            or text:match('([%a_][%w_:]*)%s+' .. name .. '%f[^%w_]')
        if found and found ~= 'return' and found ~= 'auto' then return (found:match('([%w_]+)$')) end
    end
end

local std_words = [[string vector map unordered_map set unordered_set array list deque queue stack pair tuple optional
    variant any string_view span unique_ptr shared_ptr weak_ptr make_unique make_shared move forward swap sort find
    cout cerr cin endl format function thread mutex atomic chrono filesystem ranges size_t nullptr_t exception runtime_error
    invalid_argument out_of_range begin end size min max abs]]

local members = {}
function members:is_available() return index.supported(0) end
function members:get_trigger_characters() return { '.', '>', ':' } end
function members:complete(params, callback)
    local before = params.context.cursor_before_line
    local buf = params.context.bufnr
    local typed = typed_word(params.context)

    local owner
    local scope = before:match('([%w_]+)::[%w_]*$')
    local object = before:match('([%w_]+)%s*%.[%w_]*$') or before:match('([%w_]+)%s*%->[%w_]*$')
    if scope then owner = scope
    elseif object then owner = type_of_variable(buf, object, params.context.cursor.line + 1)
    elseif not (before:match('%.[%w_]*$') or before:match('%->[%w_]*$')) then return callback({}) end

    local items, seen = {}, {}
    local all = index.entries(buf)
    local function collect(only_owner)
        for _, entry in ipairs(all) do
            local key = (entry.owner or '') .. '::' .. entry.name
            if entry.owner and (not only_owner or entry.owner == only_owner) and not seen[key] then
                seen[key] = true
                table.insert(items, item_of(entry))
            end
        end
    end
    collect(owner)

    -- 'ns::' : what is declared in the namespace (functions, types, variables, nested namespaces)
    if scope then
        for _, entry in ipairs(all) do
            local key = 'ns::' .. entry.name
            if entry.ns == scope and not entry.owner and not seen[key] then
                seen[key] = true
                table.insert(items, item_of(entry))
            end
        end
        if scope == 'std' then
            for word in std_words:gmatch('%S+') do table.insert(items, { label = word, kind = kinds.Class }) end
        end
    end
    if #items == 0 and not scope then collect(nil) end -- Unknown type: every member we know
    reply(callback, items, typed)
end

--------------------------------------------------------------------------------
-- Words of the file
--------------------------------------------------------------------------------
local words_cache = {}

-- Names already offered by the other sources (keywords, symbols): not repeated as words of the file
local function known_names(buf)
    local known = {}
    for word in (lists[vim.bo[buf].filetype] or ''):gmatch('%S+') do known[word] = true end
    if index.supported(buf) then
        for _, entry in ipairs(index.entries(buf)) do known[entry.name] = true end
    else
        for _, item in ipairs(generic_symbols(buf)) do known[item.label] = true end
    end
    return known
end

local words = {}
function words:complete(params, callback)
    local buf = params.context.bufnr
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local cached = words_cache[buf]
    if not cached or cached.tick ~= tick then
        local list, seen = {}, {}
        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 20000, false)) do
            for word in line:gmatch('[%w_]+') do
                if #word > 2 and not seen[word] then
                    seen[word] = true
                    table.insert(list, { label = word, kind = kinds.Text })
                end
            end
        end
        cached = { tick = tick, list = list }
        words_cache[buf] = cached
    end

    local typed = typed_word(params.context)
    local known = known_names(buf)
    local items = {}
    for _, item in ipairs(cached.list) do
        if item.label ~= typed and not known[item.label] then table.insert(items, item) end -- Not the word being typed
    end
    reply(callback, items, typed)
end

--------------------------------------------------------------------------------
-- Tags (menu column) and priority: the special sources come before the words of the file
--------------------------------------------------------------------------------
local tags = {
    nvim_lsp = 'LSP', keywords = 'kw', common = 'std', include = 'inc', symbols = 'sym', members = 'mem', luasnip = 'snip',
    path = 'path', words = 'file', buffer = 'file', cmdline = 'cmd',
}
local tiers = { words = 2, buffer = 2 } -- Everything else is tier 1

function M.format(entry, item)
    local tag = tags[entry.source.name] or entry.source.name
    if entry:get_kind() == kinds.Module then tag = 'ns' end -- Namespaces have their own tag
    local data = entry:get_completion_item().data
    if type(data) == 'table' and data.special then -- <guard>, <header>: skeletons of a whole file
        tag, item.kind = 'spe', 'Special'
        item.kind_hl_group, item.abbr_hl_group = 'Special', 'Special'
    end
    item.menu = '[' .. tag .. ']'
    return item
end

local function tier_comparator(entry1, entry2)
    local tier1, tier2 = tiers[entry1.source.name] or 1, tiers[entry2.source.name] or 1
    if tier1 == tier2 then return nil end
    return tier1 < tier2
end

-- Comparators of c2dmp.lua with the tier of the source right after 'exact'
function M.comparators()
    local compare = require('cmp.config.compare')
    local comparators = {}
    for _, comparator in ipairs(require('matching.c2dmp').comparators()) do
        table.insert(comparators, comparator)
        if comparator == compare.exact then table.insert(comparators, tier_comparator) end
    end
    return comparators
end

M.sources = {
    keywords = keywords, common = common, include = include, symbols = symbols, members = members, words = words,
}

function M.register()
    for name, source in pairs(M.sources) do cmp.register_source(name, source) end
end

return M
