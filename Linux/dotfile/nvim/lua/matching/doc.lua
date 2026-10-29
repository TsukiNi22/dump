-- Documentation of an entry of the index as a readable markdown: title (kind + name), file, signature, then the
-- comment cut in sections (description, parameters, return, throws, notes) when it uses @param / @return / ...
local M = {}

local labels = {
    ['function'] = 'Function', method = 'Method', type = 'Type', variable = 'Variable', member = 'Member',
    macro = 'Macro', constant = 'Constant', namespace = 'Namespace',
}
local returns = { ['return'] = true, returns = true, retval = true }
local throws = { throw = true, throws = true, exception = true }
local notes = {
    note = 'Note', warning = 'Warning', see = 'See', sa = 'See', example = 'Example', since = 'Since',
    deprecated = 'Deprecated', todo = 'Todo', pre = 'Pre', post = 'Post', attention = 'Attention',
}

-- Comment -> { text = { lines }, params = { { name, text } }, returns = {}, throws = {}, notes = { { label, text } } }
local function parse(doc)
    local result = { text = {}, params = {}, returns = {}, throws = {}, notes = {} }
    local current -- Item receiving the continuation lines

    for line in (doc .. '\n'):gmatch('(.-)\n') do
        local tag, rest = line:match('^%s*[@\\](%a+)%s*(.*)$')
        if tag then
            tag = tag:lower()
            if tag == 'brief' or tag == 'details' then
                current = { text = rest }
                table.insert(result.text, 1, current)
            elseif tag == 'param' then
                local name, text = rest:gsub('^%[[%w, ]+%]%s*', ''):match('^([%w_%.]+)%s*(.*)$')
                current = { name = name or rest, text = text or '' }
                table.insert(result.params, current)
            elseif returns[tag] then
                current = { text = rest }
                table.insert(result.returns, current)
            elseif throws[tag] then
                current = { text = rest }
                table.insert(result.throws, current)
            elseif notes[tag] then
                current = { label = notes[tag], text = rest }
                table.insert(result.notes, current)
            else
                current = { text = line }
                table.insert(result.text, current)
            end
        elseif line:match('^%s*$') then
            current = nil
            table.insert(result.text, { text = '' })
        elseif current then
            current.text = current.text .. ' ' .. vim.trim(line) -- Continuation of a tag
        else
            current = { text = line }
            table.insert(result.text, current)
            current = nil
        end
    end
    return result
end

function M.markdown(entry)
    local qualified = (entry.ns and (entry.ns .. '::') or '') .. (entry.owner and (entry.owner .. '::') or '') .. entry.name
    local lines = { '**' .. (labels[entry.kind] or 'Symbol') .. '**  `' .. qualified .. '`' }
    if entry.file then
        table.insert(lines, '*' .. vim.fn.fnamemodify(entry.file, ':t') .. (entry.line and (':' .. entry.line) or '') .. '*')
    end
    vim.list_extend(lines, { '', '```cpp', entry.signature or entry.name, '```' })

    local parsed = parse(entry.doc or '')
    local description = {}
    for _, item in ipairs(parsed.text) do table.insert(description, item.text) end
    local text = vim.trim(table.concat(description, '\n'))
    if text ~= '' then vim.list_extend(lines, { '', '---', '', text }) end

    if #parsed.params > 0 then
        vim.list_extend(lines, { '', '**Parameters**' })
        for _, param in ipairs(parsed.params) do
            table.insert(lines, '- `' .. param.name .. '`' .. (param.text ~= '' and (' — ' .. param.text) or ''))
        end
    end
    for _, item in ipairs(parsed.returns) do vim.list_extend(lines, { '', '**Returns**  ' .. item.text }) end
    for _, item in ipairs(parsed.throws) do vim.list_extend(lines, { '', '**Throws**  ' .. item.text }) end
    for _, item in ipairs(parsed.notes) do vim.list_extend(lines, { '', '**' .. item.label .. '**  ' .. item.text }) end
    return table.concat(lines, '\n')
end

return M
