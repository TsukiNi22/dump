-- Filtering of the long candidate lists (symbols, words of the file...) in a thread of libuv: the editor keeps taking keys
-- while a thread keeps the words that are near the typed word (letters in order, or close for c2dmp-hsm)
-- A newer request makes the older one useless: it is cancelled when it did not start, its answer is dropped otherwise
local M = {}

local uv = vim.uv or vim.loop
local library = vim.fn.stdpath('config') .. '/native/libc2dmp_nvim.so'

M.available = uv.new_work ~= nil
M.threshold = 300 -- Under this number of candidates the thread costs more than it saves

-- Runs in the thread (own lua state: nothing of the editor, no upvalue): indexes of the near words of the blob
local function work(typed, blob, path, max_distance)
    local distance
    local ok, ffi = pcall(require, 'ffi')
    if ok and #typed >= 4 then
        local defined = pcall(ffi.cdef, 'float c2dmp_distance(const char *a, size_t sizeA, const char *b, size_t sizeB);')
        local loaded, lib = pcall(ffi.load, path)
        if loaded then distance = function(a, b) return tonumber(lib.c2dmp_distance(a, #a, b, #b)) end end
    end

    local found, index = {}, 0
    local position = 1
    local length_typed = #typed
    while position <= #blob + 1 do
        local finish = blob:find('\n', position, true) or (#blob + 1)
        local word = blob:sub(position, finish - 1)
        index = index + 1
        position = finish + 1

        local near = typed == '' or word:find(typed, 1, true) ~= nil
        if not near then -- Letters in order
            local from = 1
            near = true
            for char in typed:gmatch('.') do
                local at = word:find(char, from, true)
                if not at then near = false break end
                from = at + 1
            end
        end
        if not near and distance then -- Inversions ('nilde' -> 'include'): words of a close length only
            local delta = #word - length_typed
            near = delta >= -2 and delta <= 5 and distance(typed, word) <= max_distance
        end
        if near then found[#found + 1] = index end
    end
    return table.concat(found, ',') -- Only strings and numbers can come back from a thread
end

-- Runs in the thread: words (3 letters or more) of a text with their number of occurrences, 'word count' per line
local function scan(text)
    local order, counts = {}, {}
    for word in text:gmatch('[%w_]+') do
        if #word > 2 then
            if counts[word] then
                counts[word] = counts[word] + 1
            else
                counts[word] = 1
                order[#order + 1] = word
            end
        end
    end
    for index, word in ipairs(order) do order[index] = word .. ' ' .. counts[word] end
    return table.concat(order, '\n')
end

local scanning = false

-- callback(list): list of { word, count } read in the thread; one scan at a time (false when one is running)
function M.scan(text, callback)
    if scanning then return false end
    scanning = true
    uv.new_work(scan, function(packed)
        scanning = false
        if type(packed) ~= 'string' then return end
        vim.schedule(function()
            local list = {}
            for word, count in packed:gmatch('(%S+) (%d+)') do list[#list + 1] = { word, tonumber(count) } end
            callback(list)
        end)
    end):queue(text)
    return true
end

local current = 0       -- Number of the last request
local pending = nil     -- Request in the thread pool, maybe not started

-- items: list of tables with .lower (kept in lower case); callback(indexes) is only called for the last request
function M.filter(items, typed, max_distance, callback)
    current = current + 1
    local id = current
    if pending then pcall(uv.cancel, pending) end -- Not started: it never runs; started: its answer is dropped below

    local blob = rawget(items, 'blob')
    if not blob then -- One string for all the words: copied once into the thread, not table by table
        local lowers = {}
        for index, item in ipairs(items) do lowers[index] = item.lower end
        blob = table.concat(lowers, '\n')
        rawset(items, 'blob', blob)
    end

    local request
    request = uv.new_work(work, function(packed)
        if pending == request then pending = nil end
        if id ~= current or type(packed) ~= 'string' then return end
        vim.schedule(function()
            if id ~= current then return end
            local found = {}
            for number in packed:gmatch('%d+') do found[#found + 1] = tonumber(number) end
            callback(found)
        end)
    end)
    pending = request
    request:queue(typed, blob, library, max_distance)
end

return M
