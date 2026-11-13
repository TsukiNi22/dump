local user = "Tsukini"

local function InsertHeaderPy()
    local filename = vim.fn.expand("%:t")
    local year = os.date("%Y")
    local header = {
        "#!/bin/env python3",
        "##",
        "## EPITECH PROJECT, " .. year,
        "## " .. filename,
        "## File description:",
        "## You know, I don t think there are good or bad descriptions,",
        "## for me, life is all about functions...",
        "##",
    }
    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

local function InsertHeaderC()
    local filename = vim.fn.expand("%:t")
    local year = os.date("%Y")
    local header = {
        "/*",
        "** EPITECH PROJECT, " .. year,
        "** " .. filename,
        "** File description:",
        "** You know, I don t think there are good or bad descriptions,",
        "** for me, life is all about functions...",
        "*/",
        "",
        "#include \"error.h\"",
    }
    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

local function InsertHeaderCPP()
    local date = os.date("%d/%m/%Y")
    local file = vim.fn.expand("%:t")
    local filename = vim.fn.expand("%:t:r")
    local header = {
        "/**************************************************************\\",
        "Edition:",
        "##  @date " .. date .. " by @author " .. user,
        "",
        "File Name:",
        "##  @file " .. file,
        "",
        "File Description:",
        "##  You know, I don t think there are good or bad descriptions,",
        "##  for me, life is all about functions...",
        "\\**************************************************************/",
    }
    -- A .cpp includes its .hpp, a .hpp doesn't include itself
    if vim.fn.expand("%:e") == "cpp" then
        vim.list_extend(header, { "", "#include \"" .. filename .. ".hpp\"" })
    end
    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

local function InsertHeaderHHeader()
    local filename = vim.fn.expand("%:t")
    local year = os.date("%Y")
    local header = {
        "/*",
        "** EPITECH PROJECT, " .. year,
        "** " .. filename,
        "** File description:",
        "** Header for the " .. filename,
        "*/",
    }
    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

-- Header of the languages with a line comment: '#' (Makefile, GAS assembly) or ';' (NASM assembly)
local function InsertHeaderLineComment(mark)
    local filename = vim.fn.expand("%:t")
    local year = os.date("%Y")
    local double = mark .. mark
    local header = {
        double,
        double .. " EPITECH PROJECT, " .. year,
        double .. " " .. filename,
        double .. " File description:",
        double .. " You know, I don t think there are good or bad descriptions,",
        double .. " for me, life is all about functions...",
        double,
        "",
    }
    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

-- Comment mark of an assembly file: ';' for NASM (.asm, .nasm, .inc), '#' for GAS (.s, .S), nil when not assembly
local function AsmCommentMark(ext)
    local filetype = vim.bo.filetype
    if filetype == "nasm" or ext == "asm" or ext == "nasm" or ext == "inc" then
        return ";"
    elseif filetype == "asm" or ext == "s" or ext == "S" then
        return "#"
    end
    return nil
end

local function InsertHeaderHaskell()
    local filename = vim.fn.expand("%:t")
    local year = os.date("%Y")
    local header = {
        "{-",
        "-- EPITECH PROJECT, " .. year,
        "-- " .. filename,
        "-- File description:",
        "-- You know, I don t think there are good or bad descriptions,",
        "-- for me, life is all about functions...",
        "-}",
        "",
    }
    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

local function InsertHeader()
    local filename = vim.fn.expand("%:t")
    local ext = vim.fn.expand("%:e")

    if ext == "py" then
        InsertHeaderPy()
    elseif ext == "c" then
        InsertHeaderC()
    elseif ext == "h" then
        InsertHeaderHHeader()
    elseif ext == "cpp" or ext == "hpp" then
        InsertHeaderCPP()
    elseif filename == "Makefile" or filename == "makefile" or ext == "mk" then
        InsertHeaderLineComment("#")
    elseif ext == "hs" then
        InsertHeaderHaskell()
    elseif AsmCommentMark(ext) then
        InsertHeaderLineComment(AsmCommentMark(ext))
    else
        print("No Epitech header defined for this type of file: " .. ext)
    end
end

return function()
    InsertHeader()
end
