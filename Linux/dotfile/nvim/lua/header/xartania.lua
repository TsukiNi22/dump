local user = "Tsukini"

local function InsertHeaderC15()
    local date = os.date("%d/%m/%Y")
    local file = vim.fn.expand("%:t")

    local header = {
    "@>************************************************************<@",
    "@",
    "@ ██╗  ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗ █████╗",
    "@ ╚██╗██╔╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║██╔══██╗",
    "@  ╚███╔╝ ███████║██████╔╝   ██║   ███████║██╔██╗ ██║██║███████║",
    "@  ██╔██╗ ██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██║██╔══██║",
    "@ ██╔╝ ██╗██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║██║  ██║",
    "@ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝",
    "@",
    "@Edition:",
    "@**  " .. date .. " by " .. user,
    "@",
    "@File Name:",
    "@**  " .. file,
    "@",
    "@File Description:",
    "@**  You know, I don t think there are good or bad descriptions,",
    "@**  for me, life is all about functions...",
    "@>************************************************************<@"
    }

    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

local function InsertHeaderPy()
    local date = os.date("%d/%m/%Y")
    local file = vim.fn.expand("%:t")
    local repeated_quotes = string.rep('"', 63)

    local header = {
    repeated_quotes,
    "",
    " ██╗  ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗ █████╗",
    " ╚██╗██╔╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║██╔══██╗",
    "  ╚███╔╝ ███████║██████╔╝   ██║   ███████║██╔██╗ ██║██║███████║",
    "  ██╔██╗ ██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██║██╔══██║",
    " ██╔╝ ██╗██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║██║  ██║",
    " ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝",
    "",
    "Edition:",
    "##  " .. date .. " by " .. user,
    "",
    "File Name:",
    "##  " .. file,
    "",
    "File Description:",
    "##  You know, I don t think there are good or bad descriptions,",
    "##  for me, life is all about functions...",
    repeated_quotes,
    }

    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

local function InsertHeaderC()
    local date = os.date("%d/%m/%Y")
    local file = vim.fn.expand("%:t")

    local header = {
    "/**************************************************************\\",
    "",
    " ██╗  ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗ █████╗",
    " ╚██╗██╔╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║██╔══██╗",
    "  ╚███╔╝ ███████║██████╔╝   ██║   ███████║██╔██╗ ██║██║███████║",
    "  ██╔██╗ ██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██║██╔══██║",
    " ██╔╝ ██╗██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║██║  ██║",
    " ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝",
    "",
    "Edition:",
    "##  " .. date .. " by " .. user,
    "",
    "File Name:",
    "##  " .. file,
    "",
    "File Description:",
    "##  You know, I don t think there are good or bad descriptions,",
    "##  for me, life is all about functions...",
    "\\**************************************************************/"
    }

    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

local function InsertHeaderCPP()
    local date = os.date("%d/%m/%Y")
    local file = vim.fn.expand("%:t")

    local header = {
    "/**************************************************************\\",
    "",
    " ██╗  ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗ █████╗",
    " ╚██╗██╔╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║██╔══██╗",
    "  ╚███╔╝ ███████║██████╔╝   ██║   ███████║██╔██╗ ██║██║███████║",
    "  ██╔██╗ ██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██║██╔══██║",
    " ██╔╝ ██╗██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║██║  ██║",
    " ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝",
    "",
    "Edition:",
    "##  @date " .. date .. " by @author " .. user,
    "",
    "File Name:",
    "##  @file " .. file,
    "",
    "File Description:",
    "##  You know, I don t think there are good or bad descriptions,",
    "##  for me, life is all about functions...",
    "\\**************************************************************/"
    }

    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

-- Header of the languages with a line comment: '#' (Makefile, GAS assembly) or ';' (NASM assembly)
local function InsertHeaderLineComment(mark)
    local date = os.date("%d/%m/%Y")
    local file = vim.fn.expand("%:t")
    local border = mark .. string.rep("*", 62) .. mark

    local header = {
    border,
    mark,
    mark .. " ██╗  ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗ █████╗",
    mark .. " ╚██╗██╔╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║██╔══██╗",
    mark .. "  ╚███╔╝ ███████║██████╔╝   ██║   ███████║██╔██╗ ██║██║███████║",
    mark .. "  ██╔██╗ ██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██║██╔══██║",
    mark .. " ██╔╝ ██╗██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║██║  ██║",
    mark .. " ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝",
    mark,
    mark .. "Edition:",
    mark .. "**  " .. date .. " by " .. user,
    mark,
    mark .. "File Name:",
    mark .. "**  " .. file,
    mark,
    mark .. "File Description:",
    mark .. "**  You know, I don t think there are good or bad descriptions,",
    mark .. "**  for me, life is all about functions...",
    border
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

local function InsertHeader()
    local filename = vim.fn.expand("%:t")
    local ext = vim.fn.expand("%:e")

    if ext == "15" or ext == "15h" then
        InsertHeaderC15()
    elseif ext == "py" then
        InsertHeaderPy()
    elseif ext == "c" or ext == "h" then
        InsertHeaderC()
    elseif ext == "cpp" or ext == "hpp" then
        InsertHeaderCPP()
    elseif filename == "Makefile" or filename == "makefile" or ext == "mk" then
        InsertHeaderLineComment("#")
    elseif AsmCommentMark(ext) then
        InsertHeaderLineComment(AsmCommentMark(ext))
    else
        print("No Xartania header defined for this type of file: " .. ext)
    end
end

return function()
    InsertHeader()
end
