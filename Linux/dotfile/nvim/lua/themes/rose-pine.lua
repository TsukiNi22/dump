return {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000, -- Colors set before anything is drawn
    config = function()
        vim.cmd.colorscheme("rose-pine")
    end
}
