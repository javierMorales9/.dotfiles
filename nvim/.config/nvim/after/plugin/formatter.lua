-- Utilities for creating configurations
local util = require("formatter.util")

local settings = {
  lua = {
    require("formatter.filetypes.lua").stylua,
  },
  typescript = {
    require("formatter.filetypes.typescript").prettier,
  },
  -- Use the special "*" filetype for defining formatter configurations on
  -- any filetype
  ["*"] = {
    -- "formatter.filetypes.any" defines default configurations for any
    -- filetype
    require("formatter.filetypes.any").remove_trailing_whitespace
  }
}

-- Provides the Format, FormatWrite, FormatLock, and FormatWriteLock commands
require("formatter").setup {
  logging = true,
  log_level = vim.log.levels.WARN,
  filetype = settings
}


vim.keymap.set("n", "<leader>lf", function()
  if settings[vim.bo.filetype] ~= nil then
    vim.cmd([[Format]])
  else
    vim.lsp.buf.format()
  end
end)
