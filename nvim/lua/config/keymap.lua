vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- quickfix and location navigation
vim.keymap.set('n', '<leader>qo', vim.cmd.copen, { desc = 'Open quickfix list' })
vim.keymap.set('n', '<leader>qc', vim.cmd.cclose, { desc = 'Close quickfix list' })
vim.keymap.set('n', ']q', vim.cmd.cnext, { desc = 'Next quickfix item' })
vim.keymap.set('n', '[q', vim.cmd.cprev, { desc = 'Previous quickfix item' })

vim.keymap.set('n', '<leader>lo', vim.cmd.lopen, { desc = 'Open location list' })
vim.keymap.set('n', '<leader>lc', vim.cmd.lclose, { desc = 'Close location list' })
vim.keymap.set('n', ']l', vim.cmd.lnext, { desc = 'Next location item' })
vim.keymap.set('n', '[l', vim.cmd.lprev, { desc = 'Previous location item' })

vim.keymap.set('n', '<C-\\>', function()
  vim.cmd 'split'
  vim.cmd 'terminal'
  vim.cmd 'startinsert'
end)
