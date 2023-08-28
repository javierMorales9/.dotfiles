local telescope = require('telescope')
local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<C-p>', builtin.git_files, {})
vim.keymap.set('n', '<leader>ps', function()
	builtin.grep_string({ search = 	vim.fn.input("Grep >") });
end)

telescope.setup{
    defaults = {
        mappings = {
            i = {
                ["<C-n>"] = "<A-j>",
                ["<C-p>"] = "<A-k>",
            }
        }
    },
    pickers = {},
    extensions = {},
}
