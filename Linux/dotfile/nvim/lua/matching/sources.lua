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

-- lower_typed: the typed word in lower case; lower_word: the word in lower case (kept on the item, computed once)
local function near_lower(lower_typed, lower_word)
    if lower_typed == '' then return true end
    if lower_word:find(lower_typed, 1, true) or subsequence(lower_typed, lower_word) then return true end
    -- c2dmp-hsm (inversions): only for words of a close length, the native call is not free
    local length = #lower_word - #lower_typed
    return c2dmp.available and #lower_typed >= 4 and length >= -2 and length <= 5
        and c2dmp.distance(lower_typed, lower_word) <= max_distance
end

local function near(typed, word) return near_lower(typed:lower(), word:lower()) end

-- Items near the typed word, whatever the cmp matcher thinks (filterText = typed), ranked by c2dmp-hsm afterwards
local threaded = require('matching.threaded')

local function reply(callback, items, typed, skip)
    local lower_typed = typed:lower()
    local filter = typed ~= '' and typed or nil
    for _, item in ipairs(items) do
        if not item.lower then item.lower = (item.match or item.label):lower() end -- Computed once per item, not at each key
    end

    local function answer(indexes)
        local result = {}
        for _, index in ipairs(indexes) do
            local item = items[index]
            if not (skip and skip(item)) then
                item.filterText = filter -- The items are shared between the requests (no copy): set again at each one
                table.insert(result, item)
            end
        end
        callback({ items = result, isIncomplete = true }) -- Asked again at every key
    end

    if threaded.available and c2dmp.available and #items >= threaded.threshold then
        -- Long list: filtered in a thread, the answer comes when it is done (dropped if a newer key made it useless)
        threaded.filter(items, lower_typed, max_distance, answer)
        return
    end

    local indexes = {}
    for index, item in ipairs(items) do
        if near_lower(lower_typed, item.lower) then table.insert(indexes, index) end
    end
    answer(indexes)
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

local item_cache = setmetatable({}, { __mode = 'k' }) -- entry -> item (the entries live as long as their file is unchanged)

local function item_of(entry)
    local item = item_cache[entry]
    if not item then
        item = {
            label = entry.name,
            kind = entry_kinds[entry.kind] or kinds.Text,
            documentation = documentation(entry),
        }
        item_cache[entry] = item
    end
    return item
end

-- Result of build() kept on the list of entries (a new list each time the file is parsed again, the old one is collected)
local function derive(name, all, build)
    local store = rawget(all, 'derived')
    if not store then store = {}; rawset(all, 'derived', store) end
    if store[name] == nil then store[name] = build() end
    return store[name]
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
local common_cache = {}
local common_available = {} -- filetype -> bool (the whole catalog was built at each key to know it)
function common:is_available()
    local filetype = vim.bo.filetype
    if common_available[filetype] == nil then
        common_available[filetype] = #require('matching.common').items(filetype, 'top') > 0
    end
    return common_available[filetype]
end
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

    -- Each reading filters with its own typed word; the items of a reading are built once (the catalog is rebuilt
    -- every 30 s: the date of the headers, the new files)
    local result = {}
    for _, reading in ipairs(contexts) do
        local key = filetype .. '\0' .. reading[1] .. '\0' .. name
        local cached = common_cache[key]
        if not cached or os.time() - cached.time > 30 then
            local items = {}
            for _, entry in ipairs(catalog.items(filetype, reading[1], file)) do
                table.insert(items, {
                    label = entry.label, match = entry.match, strict = entry.strict, kind = kinds[entry.kind] or kinds.Snippet,
                    insertText = entry.snippet, insertTextFormat = 2, -- 2: snippet (the fields are jumped with Tab)
                    documentation = { kind = 'markdown', value = '**Common**\n\n' .. entry.doc },
                    data = { group = entry.group, rank = entry.rank, special = entry.special },
                    lower = (entry.match or entry.label):lower(),
                })
            end
            cached = { time = os.time(), items = items }
            common_cache[key] = cached
        end
        local typed = reading[2]
        local lower_typed = typed:lower()
        for _, item in ipairs(cached.items) do
            -- A line that only holds a word ('def'): the exact letters only, so that '#define' does not appear for every word
            local found = item.strict and item.lower:find(lower_typed, 1, true) or (not item.strict and near_lower(lower_typed, item.lower))
            if found then
                item.filterText = typed ~= '' and typed or nil
                table.insert(result, item)
            end
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
    if cached and (cached.tick == tick or vim.uv.now() - cached.time < 400) then return cached.items end -- Not at each key

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
    generic_cache[buf] = { tick = tick, items = items, time = vim.uv.now() }
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
        local all = index.entries(buf)
        items = derive('symbols', all, function()
            local list, seen = {}, {}
            for _, entry in ipairs(all) do
                local scoped = entry.owner and entry.kind ~= 'constant'
                if not scoped and not seen[entry.name] then
                    seen[entry.name] = true
                    table.insert(list, item_of(entry))
                end
            end
            return list
        end)
    else
        for _, item in ipairs(generic_symbols(buf)) do
            if item.label ~= typed then table.insert(items, item) end
        end
    end
    reply(callback, items, typed) -- The exact word is offered too (the menu is closed when it is the only choice)
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

    local all = index.entries(buf)
    local groups = derive('members', all, function() -- Owned entries and entries of the namespaces, built once per parse
        local owned, namespaced, seen = {}, {}, {}
        for _, entry in ipairs(all) do
            local key = (entry.owner or '') .. '::' .. entry.name
            if entry.owner and not seen[key] then
                seen[key] = true
                table.insert(owned, entry)
            end
            local ns_key = 'ns::' .. (entry.ns or '') .. '::' .. entry.name
            if entry.ns and not entry.owner and not seen[ns_key] then
                seen[ns_key] = true
                table.insert(namespaced, entry)
            end
        end
        return { owned = owned, namespaced = namespaced }
    end)

    local items = {}
    for _, entry in ipairs(groups.owned) do
        if entry.owner == owner then table.insert(items, item_of(entry)) end
    end

    -- 'ns::' : what is declared in the namespace (functions, types, variables, nested namespaces)
    if scope then
        for _, entry in ipairs(groups.namespaced) do
            if entry.ns == scope then table.insert(items, item_of(entry)) end
        end
        if scope == 'std' then
            for _, item in ipairs(items_of('std_words', std_words, kinds.Class)) do table.insert(items, item) end
        end
    end
    if #items == 0 and not scope then -- Unknown type: every member we know
        for _, entry in ipairs(groups.owned) do table.insert(items, item_of(entry)) end
    end
    reply(callback, items, typed)
end

--------------------------------------------------------------------------------
-- Words of the file
--------------------------------------------------------------------------------
local words_cache = {}

-- Names already offered by the other sources (keywords, symbols): not repeated as words of the file
local function known_names(buf)
    local source = index.supported(buf) and index.entries(buf) or generic_symbols(buf) -- Same table while nothing is parsed again
    return derive('known' .. vim.bo[buf].filetype, source, function()
        local known = {}
        for word in (lists[vim.bo[buf].filetype] or ''):gmatch('%S+') do known[word] = true end
        if index.supported(buf) then
            for _, entry in ipairs(source) do known[entry.name] = true end
        else
            for _, item in ipairs(source) do known[item.label] = true end
        end
        return known
    end)
end

local words = {}
function words:complete(params, callback)
    local buf = params.context.bufnr
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local cached = words_cache[buf]
    local function as_items(list)
        local items = {}
        for index, entry in ipairs(list) do items[index] = { label = entry[1], kind = kinds.Text, count = entry[2] } end
        return items
    end
    if not cached then -- First time: read at once (the prewarm does it while nobody types)
        local list = {}
        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 20000, false)) do
            for word in line:gmatch('[%w_]+') do
                if #word > 2 then
                    local entry = list[word]
                    if entry then entry[2] = entry[2] + 1 else entry = { word, 1 }; list[word] = entry; table.insert(list, entry) end
                end
            end
        end
        cached = { tick = tick, list = as_items(list), time = vim.uv.now() }
        words_cache[buf] = cached
    elseif cached.tick ~= tick and vim.uv.now() - cached.time > 400 then
        -- The words are read again in a thread (the current list is used meanwhile), not at each key
        local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, 20000, false), '\n')
        threaded.scan(text, function(list)
            words_cache[buf] = { tick = tick, list = as_items(list), time = vim.uv.now() }
        end)
        cached.time = vim.uv.now()
    end

    local typed = typed_word(params.context)
    local known = known_names(buf)
    local items = derive('words' .. tostring(known), cached.list, function() -- Without the names the other sources already offer
        local list = {}
        for _, item in ipairs(cached.list) do
            if not known[item.label] then table.insert(list, item) end
        end
        return list
    end)
    -- The word being typed is in the file (once, at the cursor) and so are the beginnings typed before it ('_mo' for
    -- '_mono'): only a word written elsewhere too is offered
    reply(callback, items, typed, function(item)
        return item.count < 2 and #item.label <= #typed and typed:sub(1, #item.label) == item.label
    end)
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

-- Builds the caches of every source for a buffer (symbols of the includes, words, catalog) while nobody types: the
-- first completion does not pay for them
function M.prewarm(buf)
    if vim.api.nvim_get_current_buf() ~= buf or not vim.api.nvim_buf_is_loaded(buf) then return end
    local params = { context = { bufnr = buf, cursor_before_line = '', cursor = { line = 0 } } }
    for _, name in ipairs({ 'symbols', 'words', 'common', 'keywords' }) do
        local source = M.sources[name]
        if not source.is_available or source:is_available() then
            pcall(source.complete, source, params, function() end)
        end
    end
end

function M.register()
    for name, source in pairs(M.sources) do cmp.register_source(name, source) end
end

return M
