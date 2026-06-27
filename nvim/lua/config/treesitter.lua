local nix_ts_root = '/home/wyatt/.local/share/tree-sitter/tree-sitter-nix/result'

vim.opt.runtimepath:append(nix_ts_root)

vim.treesitter.language.add('nix', {
  path = nix_ts_root .. '/parser',
})


vim.treesitter.language.register('nix', {'nix'})

local ts_enabled = {
  bash = true,
  c = true,
  cpp = true,
  c_sharp = true,
  css = true,
  html = true,
  javascript = true,
  json = true,
  lua = true,
  nix = false,
  python = true,
  rust = true,
  typescript = true,
  tsx = true,
  vim = true,
  vimdoc = true,
}

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('native-treesitter', { clear = true }),
  callback = function(event)
    local ft = vim.bo[event.buf].filetype
    local lang = vim.treesitter.language.get_lang(ft)

    if not lang or not ts_enabled[lang] then
      return
    end

    local ok, err = pcall(vim.treesitter.start, event.buf, lang)
    if not ok then
      vim.notify(('treesitter failed for %s: %s'):format(lang, err), vim.log.levels.WARN)
    end
  end,
})
