require 'config.global'
require 'config.options'
require 'config.keymap'

vim.filetype.add {
  extension = {
    uss = 'css',
    uxml = 'xml',
  },
}

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

require 'config.lazy'
require 'config.lsp'
require 'config.treesitter'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
