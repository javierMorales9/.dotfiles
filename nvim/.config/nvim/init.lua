require("javi")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "sql",
  callback = function()
    vim.api.nvim_del_keymap("i", "<C-c>")
  end,
})
