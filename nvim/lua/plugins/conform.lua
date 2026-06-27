return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format {
          async = true,
          lsp_format = 'fallback',
        }
      end,
      mode = '',
      desc = '[F]ormat buffer',
    },
  },
  opts = {
    formatters_by_ft = {
      bash = { 'shfmt' },
      cs = { 'csharpier' },
      javascript = { 'prettier' },
      javascriptreact = { 'prettier' },
      lua = { 'stylua' },
      nix = { 'nixfmt' },
      rust = { 'rustfmt' },
      sh = { 'shfmt' },
      typescript = { 'prettier' },
      typescriptreact = { 'prettier' },
    },
  },
  config = function(_, opts)
    require('conform').setup(opts)
    vim.api.nvim_create_autocmd('BufWritePre', {
      pattern = '*',
      callback = function(args)
        require('conform').format { bufnr = args.buf }
      end,
    })
  end,
}
