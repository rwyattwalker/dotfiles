return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    local treesitter = require 'nvim-treesitter'
    local parsers = { 'rust', 'javascript', 'nix', 'lua', 'c_sharp', 'bash', 'yaml', 'xml' }

    treesitter.setup {
      install_dir = vim.fn.stdpath 'data' .. '/site',
    }
    treesitter.install(parsers)

    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'rs', 'js', 'nix', 'lua', 'cs', 'sh', 'yaml', 'yml', 'proj', 'xml' },
      callback = function()
        vim.treesitter.start()
      end,
    })
  end,
}
