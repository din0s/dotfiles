-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Options
vim.opt.tabstop = 4               -- tab displays as 4 spaces
vim.opt.softtabstop = 4           -- tab key inserts 4 spaces
vim.opt.shiftwidth = 4            -- indent/outdent by 4 spaces
vim.opt.expandtab = true          -- use spaces instead of tab characters
vim.opt.number = true             -- show line numbers
vim.opt.relativenumber = true     -- line numbers relative to cursor
vim.opt.title = true              -- set terminal title to filename
vim.opt.ignorecase = true         -- case-insensitive search...
vim.opt.smartcase = true          -- ...unless query has uppercase
vim.opt.scrolloff = 8             -- keep 8 lines visible above/below cursor
vim.opt.signcolumn = "yes"        -- always show sign column (prevents gutter jitter)
vim.opt.updatetime = 300          -- faster CursorHold events (default 4000ms)
vim.opt.clipboard = "unnamedplus" -- yank/paste uses system clipboard
vim.opt.undofile = true           -- persist undo history across sessions

-- Python indent: use shiftwidth (not 2x) inside brackets
vim.g.python_indent = {
    open_paren = "shiftwidth()",
    nested_paren = "shiftwidth()",
    continue = "shiftwidth()",
    closed_paren_align_last_line = true,
    disable_parentheses_indenting = false,
    searchpair_timeout = 150,
}

-- Plugins
require("lazy").setup({
    -- Statusline
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            options = { theme = "auto" },
        },
    },

    -- Colorscheme
    {
        "Shatur/neovim-ayu",
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("ayu-dark")
        end,
    },
})
