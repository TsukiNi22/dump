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

local function InsertHeaderMakefile()
    local date = os.date("%d/%m/%Y")
    local file = vim.fn.expand("%:t")

    local header = {
    "#**************************************************************#",
    "#",
    "# ██╗  ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗ █████╗",
    "# ╚██╗██╔╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║██╔══██╗",
    "#  ╚███╔╝ ███████║██████╔╝   ██║   ███████║██╔██╗ ██║██║███████║",
    "#  ██╔██╗ ██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██║██╔══██║",
    "# ██╔╝ ██╗██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║██║  ██║",
    "# ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝",
    "#",
    "#Edition:",
    "#**  " .. date .. " by " .. user,
    "#",
    "#File Name:",
    "#**  " .. file,
    "#",
    "#File Description:",
    "#**  You know, I don t think there are good or bad descriptions,",
    "#**  for me, life is all about functions...",
    "#**************************************************************#"
    }

    vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
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
        InsertHeaderMakefile()
    else
        print("No Xartania header defined for this type of file: " .. ext)
    end
end

return function()
    InsertHeader()
end
