-- Shift+Enter behaves like Escape in every mode
vim.keymap.set({ "", "!" }, "<S-CR>", "<Esc>")
vim.keymap.set("t", "<S-CR>", "<C-\\><C-n>")

-- "jj" in insert mode returns to normal mode
vim.keymap.set("i", "jj", "<Esc>")
