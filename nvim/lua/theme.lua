return {
  -- To see what colorschemes are already installed, you can use `:Telescope colorscheme`.
  'folke/tokyonight.nvim',
  priority = 1000, -- Make sure to load this before all the other start plugins.
  config = function()
    ---@diagnostic disable-next-line: missing-fields
    require('tokyonight').setup {
      styles = {
        comments = { italic = false },
      },
    }
    vim.cmd.colorscheme 'tokyonight-night'
  end,
}
--{
-- 'navarasu/onedark.nvim',
--priority = 1000, -- Make sure to load this before all the other start plugins.
--config = function()
-- require('onedark').setup {
--  style = 'warmer',
--  comments = { italic = false },
--  }
-- require('onedark').load()
--end,
--},
-- Highlight todo, notes, etc in comments
