local telescope = require('telescope')
local actions = require('telescope.actions')
local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<C-p>', builtin.git_files, {})
vim.keymap.set("n", "<leader>re",
  [[<cmd>lua require('telescope').extensions.recent_files.pick()<CR>]],
  { noremap = true, silent = true })

vim.keymap.set(
  "n",
  "<leader>ff",
  ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>"
)

vim.keymap.set(
  "n",
  "<leader>ld",
  ":lua require('telescope.builtin').diagnostics()<CR>"
)
-- To do find replace follow:
-- 1. Call <leader>ff and search for a pattern.
-- 2. When you get the list for results in telescope do <C-q> to move 
--    them to a quick list
-- 3. Now to replace do 
--      :cdo s/<previous string>/<new string>/gc to confirm each replace
--      :cdo s/<previous string>/<new string>/g to just do them all



telescope.setup {
  defaults = {
    mappings = {
      i = {
        ["<A-j>"] = actions.move_selection_next,
        ["<A-k>"] = actions.move_selection_previous,
      }
    }
  },
  pickers = {},
  extensions = {
    recent_files = {
      only_cwd = true
    }
  },
}
