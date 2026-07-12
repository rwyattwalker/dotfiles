return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'
    local netcoredbg = vim.fn.exepath 'netcoredbg'

    vim.fn.sign_define('DapBreakpoint', { text = '', texthl = 'DapBreakpoint', linehl = '', numhl = '' }) --●
    vim.fn.sign_define('DapStopped', { text = '', texthl = 'DapStopped', linehl = '', numhl = '' })
    vim.fn.sign_define('DapBreakpointRejected', { text = '✖', texthl = 'DapBreakpointRejected', linehl = '', numhl = '' })

    vim.cmd 'highlight DapBreakpoint guifg=#ff9e64'
    vim.cmd 'highlight DapStopped guifg=#9ece6a' --9ece6a
    vim.cmd 'highlight DapBreakpointRejected guifg=#FFA500'

    --  Helper function to build project
    vim.g.dotnet_build_project = function()
      local cmd = 'dotnet build -c Debug'
      os.execute(cmd)
    end

    dap.adapters.coreclr = {
      type = 'executable',
      command = netcoredbg,
      args = { '--interpreter=vscode' },
    }

    dap.configurations.cs = {
      {
        type = 'coreclr',
        name = 'Launch',
        request = 'launch',
        console = 'externalTerminal',
        program = function()
          vim.g.dotnet_build_project()
          return coroutine.create(function(coro)
            require('telescope.builtin').find_files {
              prompt_title = 'Select DLL',
              cwd = vim.fn.getcwd(),
              search_dirs = { 'bin/Debug' }, -- Optional narrowing
              find_command = { 'rg', '--files', '-g', '*.dll' },
              previewer = false,
              attach_mappings = function(prompt_bufnr, map)
                local actions = require 'telescope.actions'
                local action_state = require 'telescope.actions.state'

                local get_selection = function()
                  local entry = action_state.get_selected_entry()
                  actions.close(prompt_bufnr)
                  coroutine.resume(coro, entry.path)
                end

                map('i', '<CR>', get_selection)
                map('n', '<CR>', get_selection)

                return true
              end,
            }
          end)
        end,
      },
    }

    dapui.setup {
      layouts = {
        {
          elements = {
            { id = 'scopes', size = 0.5 },
            { id = 'stacks', size = 0.5 },
          },
          size = 40,
          position = 'left',
        },
        {
          elements = {
            { id = 'repl', size = 1.0 },
          },
          size = 10,
          position = 'bottom',
        },
      },
    }

    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open()
    end

    dap.listeners.before.event_terminated['dapui_config'] = function()
      dapui.close()
    end

    dap.listeners.before.event_exited['dapui_config'] = function()
      dapui.close()
    end

    --  KEYMAP
    vim.keymap.set('n', '<F5>', function()
      require('dap').continue()
    end, { desc = 'Continue' })

    -- Shift + F5
    vim.keymap.set('n', '<F17>', function()
      require('dap').terminate()
    end, { desc = 'Terminate Debugging Session' })

    vim.keymap.set('n', '<F10>', function()
      require('dap').step_over()
    end, { desc = 'Step Over' })

    vim.keymap.set('n', '<F11>', function()
      require('dap').step_into()
    end, { desc = 'Step Into' })

    -- Shift + F11
    vim.keymap.set('n', '<F23>', function()
      require('dap').step_out()
    end, { desc = 'Step Out' })

    vim.keymap.set('n', '<Leader>b', function()
      require('dap').toggle_breakpoint()
    end, { desc = 'Toggle Breakpoint' })

    -- Ctrl - F5
    vim.keymap.set('n', '<Leader>dl', function()
      require('dap').run_last()
    end, { desc = 'Run Last Debug Configuration' })
  end,
}
