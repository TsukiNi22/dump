-- c2dmp-hsm (libutils, normal mode) as the ranking of the completion
-- The shared library is built by native/build.sh, without it everything falls back to the default ranking
local M = {}

local lib = nil
local ok, ffi = pcall(require, 'ffi')
local path = vim.fn.stdpath('config') .. '/native/libc2dmp_nvim.so'

if ok and (vim.uv or vim.loop).fs_stat(path) then
    ffi.cdef [[ float c2dmp_distance(const char *a, size_t sizeA, const char *b, size_t sizeB); ]]
    local loaded, library = pcall(ffi.load, path)
    if loaded then lib = library end
end

M.available = lib ~= nil

-- Distance between the typed word and a candidate (the lower the closer)
function M.distance(typed, word)
    return tonumber(lib.c2dmp_distance(typed, #typed, word, #word))
end

-- Word being typed before the cursor
local function typed_word(entry)
    return entry.context.cursor_before_line:match('[%w_%-]*$') or ''
end

-- Number of typed letters found in the word (each letter counted once per occurrence), order ignored
local function coverage(typed, word)
    local remaining, count = word:lower(), 0
    for char in typed:lower():gmatch('.') do
        local position = remaining:find(char, 1, true)
        if position then
            remaining = remaining:sub(1, position - 1) .. remaining:sub(position + 1)
            count = count + 1
        end
    end
    return count
end

-- The forms of one common thing (the word main, its skeletons) are ranked as the same word, the form the context prefers
-- (data.rank = 1) just before the others
local function word_of(entry)
    local data = entry:get_completion_item().data
    if type(data) == 'table' and data.group then return data.group, (data.rank or 1) * 0.01 end
    return entry:get_word(), 0
end

-- Coverage and distance of an entry, computed once for the typed word (a sort asks them again for each comparison)
local function scores(entry, typed)
    local cached = entry.c2dmp_scores
    if cached and cached.typed == typed then return cached end
    local word, handicap = word_of(entry)
    cached = { typed = typed, cover = coverage(typed, word), word = word, handicap = handicap }
    entry.c2dmp_scores = cached
    return cached
end

local function distance_of(scored)
    if not scored.distance then scored.distance = M.distance(scored.typed, scored.word) + scored.handicap end
    return scored.distance
end

-- nvim-cmp comparator: the candidate holding the most typed letters first, then the closest for c2dmp-hsm
function M.comparator(entry1, entry2)
    local typed = typed_word(entry1)
    if typed == '' then return nil end

    local scored1, scored2 = scores(entry1, typed), scores(entry2, typed)
    if scored1.cover ~= scored2.cover then return scored1.cover > scored2.cover end

    local dist1, dist2 = distance_of(scored1), distance_of(scored2)
    if dist1 == dist2 then return nil end
    return dist1 < dist2
end

-- Default comparators of nvim-cmp with c2dmp-hsm instead of the fuzzy score
function M.comparators()
    local compare = require('cmp.config.compare')
    local comparators = {}
    for _, comparator in ipairs(require('cmp.config.default')().sorting.comparators) do
        if comparator == compare.score and M.available then
            table.insert(comparators, M.comparator)
        end
        table.insert(comparators, comparator)
    end
    return comparators
end

return M
