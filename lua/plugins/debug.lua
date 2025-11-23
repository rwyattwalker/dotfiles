return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    vim.fn.sign_define('DapBreakpoint', { text = '', texthl = 'DapBreakpoint', linehl = '', numhl = '' }) --●
    vim.fn.sign_define('DapStopped', { text = '', texthl = 'DapStopped', linehl = '', numhl = '' })
    vim.fn.sign_define('DapBreakpointRejected', { text = '✖', texthl = 'DapBreakpointRejected', linehl = '', numhl = '' })

    vim.cmd 'highlight DapBreakpoint guifg=#ff9e64'
    vim.cmd 'highlight DapStopped guifg=#9ece6a' --9ece6a
    vim.cmd 'highlight DapBreakpointRejected guifg=#FFA500'
    --  Helper function to build project
    vim.g.dotnet_build_project = function()
      local default_path = vim.fn.getcwd() .. '\\'
      if vim.g['dotnet_last_proj_path'] ~= nil then
        default_path = vim.g['dotnet_last_proj_path']
      end
      local path = vim.fn.input('Path to your csproj file ', default_path, 'file')
      vim.g['dotnet_last_proj_path'] = path
      local cmd = 'dotnet build -c Debug ' .. path .. '"'
      print ''
      print('Cmd to execute: ' .. cmd)
      local f = os.execute(cmd)
      if f == 0 then
        print '\nBuild: ✔️ '
      else
        print('\nBuild: ❌ (code: ' .. f .. ')')
      end
    end

    dap.adapters.coreclr = {
      type = 'executable',
      command = vim.fn.expand '~' .. '/scoop/shims/netcoredbg.exe',
      args = { '--interpreter=vscode' },
    }
    dap.configurations.cs = {
      {
        type = 'coreclr',
        name = 'Launch',
        request = 'launch',
        console = 'integratedTerminal',
        program = function()
          if vim.fn.confirm('Should I recompile first?', '&yes\n&no', 2) == 1 then
            vim.g.dotnet_build_project()
          end
          return coroutine.create(function(coro)
            require('telescope.builtin').find_files {
              prompt_title = 'Select DLL',
              cwd = vim.fn.getcwd(),
              search_dirs = { 'bin/Debug' }, -- Optional narrowing
              find_command = { 'fd', '--extension', 'dll' },

              previewer = false,

              attach_mappings = function(prompt_bufnr, map)
                local actions = require 'telescope.actions'
                local action_state = require 'telescope.actions.state'

                map('i', '<CR>', function()
                  local entry = action_state.get_selected_entry()
                  actions.close(prompt_bufnr)
                  coroutine.resume(coro, entry.path)
                end)

                map('n', '<CR>', function()
                  local entry = action_state.get_selected_entry()
                  actions.close(prompt_bufnr)
                  coroutine.resume(coro, entry.path)
                end)

                return true
              end,
            }
          end)
        end,
      },
    }
    dapui.setup()
    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated['dapui_config'] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited['dapui_config'] = function()
      dapui.close()
    end

    vim.keymap.set('n', '<F5>', function()
      require('dap').continue()
    end)
    vim.keymap.set('n', '<F10>', function()
      require('dap').step_over()
    end)
    vim.keymap.set('n', '<F11>', function()
      require('dap').step_into()
    end)
    vim.keymap.set('n', '<F12>', function()
      require('dap').step_out()
    end)
    vim.keymap.set('n', '<Leader>b', function()
      require('dap').toggle_breakpoint()
    end)
    vim.keymap.set('n', '<Leader>B', function()
      require('dap').set_breakpoint()
    end)
    vim.keymap.set('n', '<Leader>lp', function()
      require('dap').set_breakpoint(nil, nil, vim.fn.input 'Log point message: ')
    end)
    vim.keymap.set('n', '<Leader>dr', function()
      require('dap').repl.open()
    end)
    vim.keymap.set('n', '<Leader>dl', function()
      require('dap').run_last()
    end)
    vim.keymap.set({ 'n', 'v' }, '<Leader>dh', function()
      require('dap.ui.widgets').hover()
    end)
    vim.keymap.set({ 'n', 'v' }, '<Leader>dp', function()
      require('dap.ui.widgets').preview()
    end)
    vim.keymap.set('n', '<Leader>df', function()
      local widgets = require 'dap.ui.widgets'
      widgets.centered_float(widgets.frames)
    end)
    vim.keymap.set('n', '<Leader>ds', function()
      local widgets = require 'dap.ui.widgets'
      widgets.centered_float(widgets.scopes)
    end)
  end,
}
