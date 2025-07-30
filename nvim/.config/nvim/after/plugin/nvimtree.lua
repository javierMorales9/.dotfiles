local nvimtree = require('nvim-tree')
local api = require('nvim-tree.api')

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true

vim.keymap.set('n', '<A-p>', api.node.navigate.parent_close)
vim.keymap.set('n', '<leader>ls', ':NvimTreeToggle<CR>', { desc = 'Toggle NvimTree' })

nvimtree.setup{
  actions = {
    open_file = {
      quit_on_open = true,
    },
  },
  view = {
    float = {
      quit_on_focus_loss = true,
    }
  },
  sync_root_with_cwd = true,
  respect_buf_cwd = true,
  update_focused_file = {
    enable = true,
    update_root = true
  },
  git = {
    enable = true,
    ignore = false,
    timeout = 500,
  },
}
