return {
  'saghen/blink.cmp',
  dependencies = {
    'saghen/blink.lib',
    -- optional: provides snippets for the snippet source
    'rafamadriz/friendly-snippets',
  },
  build = function()
    -- build the fuzzy matcher, optionally add a timeout to `pwait(timeout_ms)`
    -- you can use `gb` in `:Lazy` to rebuild the plugin as needed
    require('blink.cmp').build():pwait()
  end,

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = { preset = 'enter' },
    completion = {
      documentation = { auto_show = false },
      list = { selection = { preselect = false } },
    },
    sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
    fuzzy = { implementation = 'rust' },
  },
}
