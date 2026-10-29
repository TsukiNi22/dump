return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- The main branch doesn't support lazy-loading
    build = ":TSUpdate",
    config = function()
        -- Queries of this config instead of the installed ones (a file of the runtime path cannot replace a query that
        -- "inherits" another one): light C++ highlights, no injections for C / C++ (see queries/cpp/highlights.scm)
        local file = io.open(vim.fn.stdpath('config') .. '/queries/cpp/highlights.scm', 'r')
        if file then
            vim.treesitter.query.set('cpp', 'highlights', file:read('*a'))
            file:close()
        end
        vim.treesitter.query.set('cpp', 'injections', '')
        vim.treesitter.query.set('c', 'injections', '')

        -- Needs tree-sitter-cli + a C compiler (async, done once)
        vim.defer_fn(function() -- After the start: checking the parsers is not needed to display the first file
            require("nvim-treesitter").install({
                "c", "cpp", "python", "lua", "bash",
                "markdown", "make", "cmake", "json", "yaml",
            })
        end, 1000)
        vim.api.nvim_create_autocmd("FileType", {
            pattern = { "c", "cpp", "python", "lua", "bash", "sh", "markdown", "make", "cmake", "json", "yaml" },
            callback = function(args)
                -- After the first draw: compiling the highlight query of C++ takes ~0.5 s the first time, the text must not wait for it
                vim.defer_fn(function()
                    if vim.api.nvim_buf_is_valid(args.buf) and vim.bo[args.buf].filetype ~= '' then
                        pcall(vim.treesitter.start, args.buf) -- Parser not installed yet -> default highlight
                    end
                end, 10)
            end,
        })
        -- Nothing opened at start: the queries of C / C++ are compiled while nobody types yet (the next file opens at once)
        vim.api.nvim_create_autocmd('VimEnter', {
            once = true,
            callback = function()
                if vim.fn.argc() > 0 then return end
                vim.defer_fn(function()
                    if vim.fn.mode() ~= 'n' then return end
                    for _, lang in ipairs({ 'c', 'cpp' }) do
                        pcall(vim.treesitter.language.add, lang)
                        pcall(vim.treesitter.query.get, lang, 'highlights')
                    end
                end, 400)
            end,
        })
    end,
}
