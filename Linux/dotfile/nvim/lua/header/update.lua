local user = "Tsukini"
local HEADER_MAX_LINES = 30 -- The header is searched only at the start of the file

-- First line of the Xartania / Epitech C++ headers
local header_borders = {
    ["/**************************************************************\\"] = true,
    ["@>************************************************************<@"] = true,
    ["#**************************************************************#"] = true,
    [string.rep('"', 63)] = true,
}

-- Update the edition date of the header when the file is saved
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    callback = function(args)
        local bufnr = args.buf
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, HEADER_MAX_LINES, false)
        local header_found = false

        for i, line in ipairs(lines) do
            if header_borders[line] then
                header_found = true
            end
            local prefix = line:match("^([#@]?)Edition:$")
            if header_found and prefix and lines[i + 1] then
                local ext = vim.fn.fnamemodify(args.file, ":e")
                local date = os.date("%d/%m/%Y")
                local mark = prefix == "" and "##" or prefix .. "**" -- "#**" / "@**" for the Makefile / C15 headers
                -- The author already written is kept, even blank (the header snippet leaves it to fill in)
                local current = lines[i + 1]
                local author = current:match("by @author%s*(.-)%s*$") or current:match(" by%s*(.-)%s*$") or user
                local new_line = mark .. "  " .. date .. " by" .. (author ~= "" and (" " .. author) or "")

                if ext == "cpp" or ext == "hpp" then
                    new_line = mark .. "  @date " .. date .. " by @author" .. (author ~= "" and (" " .. author) or "")
                end
                if lines[i + 1] ~= new_line then
                    vim.api.nvim_buf_set_lines(bufnr, i, i + 1, false, { new_line })
                end
                return
            end
        end
    end,
})
