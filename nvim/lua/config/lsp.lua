vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, {
        buffer = event.buf,
        desc = 'LSP: ' .. desc,
      })
    end

    vim.keymap.set('n', 'grd', function()
      vim.lsp.buf.definition { loclist = true }
    end, { buffer = event.buf, desc = 'Goto definition' })

    vim.keymap.set('n', 'gri', function()
      vim.lsp.buf.implementation { loclist = true }
    end, { buffer = event.buf, desc = 'Goto implementation' })

    vim.keymap.set('n', 'grt', function()
      vim.lsp.buf.type_definition { loclist = true }
    end, { buffer = event.buf, desc = 'Goto type definition' })

    vim.keymap.set('n', 'grD', function()
      vim.lsp.buf.declaration { loclist = true }
    end, { buffer = event.buf, desc = 'Goto declaration' })

    vim.keymap.set('n', 'grr', function()
      vim.lsp.buf.references(nil, { loclist = true })
    end, { buffer = event.buf, desc = 'Goto references' })

    vim.keymap.set('n', 'gO', function()
      vim.lsp.buf.document_symbol { loclist = true }
    end, { buffer = event.buf, desc = 'Document symbols' })

    vim.keymap.set('n', 'gra', function()
      vim.lsp.buf.code_action()
    end, { buffer = event.buf, desc = 'Code action' })

    -- These mappings override the default nvim lsp keymaps which use quick fix

    -- map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
    -- map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

    --  map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
    --  map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
    --  map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
    --  map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

    --  map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')
    --  map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
    --  map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then
      return
    end

    if client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
      local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })

      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds {
            group = 'kickstart-lsp-highlight',
            buffer = event2.buf,
          }
        end,
      })
    end

    if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
      map('<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }, { bufnr = event.buf })
      end, '[T]oggle Inlay [H]ints')
    end

    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        vim.lsp.diagnostic._refresh(event.buf, client.id)
      end
    end, 3000)
  end,
})

--
-- Diagnostics
--
vim.diagnostic.config {
  severity_sort = true,
  float = {
    border = 'rounded',
    source = 'if_many',
  },
  underline = {
    severity = vim.diagnostic.severity.ERROR,
  },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_text = {
    source = 'if_many',
    spacing = 2,
    format = function(diagnostic)
      return diagnostic.message
    end,
  },
}

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

vim.lsp.config('rust_analyzer', {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', 'rust-project.json', '.git' },
})

vim.lsp.config('nixd', {
  cmd = { 'nixd' },
  filetypes = { 'nix' },
  root_markers = { 'flake.nix', 'default.nix', '.git' },
})

vim.lsp.config('pylsp', {
  cmd = { 'pylsp' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
})

vim.lsp.config('ts_ls', {
  cmd = { 'typescript-language-server', '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
  },
  root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
})

vim.lsp.config('clangd', {
  cmd = { 'clangd' },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  root_markers = { 'compile_commands.json', 'compile_flags.txt', '.clangd', '.git' },
})
vim.lsp.config('roslyn', {
  cmd = {
    'Microsoft.CodeAnalysis.LanguageServer',
    '--stdio',
    '--autoLoadProjects',
    '--logLevel',
    'Information',
  },
  filetypes = { 'cs' },

  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)

    local root_file = vim.fs.find(function(name)
      return name:match '%.sln$' or name:match '%.slnx$' or name:match '%.csproj$' or name == '.git'
    end, {
      path = fname,
      upward = true,
    })[1]

    if root_file then
      on_dir(vim.fs.dirname(root_file))
    end
  end,
})
--vim.lsp.config('csharp_ls', {
--      cmd = { 'csharp-ls' },
--  filetypes = { 'cs' },
--  root_markers = { '*.sln', '*.csproj', '.git' },
--})

vim.lsp.config('bashls', {
  cmd = { 'bash-language-server', 'start' },
  filetypes = { 'bash', 'sh' },
  root_markers = { '.git' },
})

vim.lsp.config('lua_ls', {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = {
    '.luarc.json',
    '.luarc.jsonc',
    '.luacheckrc',
    '.stylua.toml',
    'stylua.toml',
    'selene.toml',
    'selene.yml',
    '.git',
  },
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
      },
      diagnostics = {
        globals = { 'vim' },
      },
      workspace = {
        checkThirdParty = false,
        library = vim.api.nvim_get_runtime_file('', true),
      },
      telemetry = {
        enable = false,
      },
    },
  },
})
--
-- Server-specific overrides, only when needed
--
-- Example:
-- vim.lsp.config('rust_analyzer', {
--   cmd = { '/run/current-system/sw/bin/rust-analyzer' },
-- })

--
-- Enable servers
--
vim.lsp.enable {
  'rust_analyzer',
  'nixd',
  'pylsp',
  'ts_ls',
  'clangd',
  'roslyn',
  'bashls',
  'lua_ls',
}
