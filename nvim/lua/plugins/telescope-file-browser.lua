return {
  'nvim-telescope/telescope-file-browser.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim', 'nvim-lua/plenary.nvim' },
  config = function()
    vim.keymap.set('n', '\\', ':Telescope file_browser<CR>')
  end,
}

-- The `file_browser` picker comes pre-configured with several keymaps:
-- • `<cr>` : Opens the currently selected file/directory, or creates whatever is
--   in the prompt
-- • `<s-cr>` : Create path in prompt
-- • `/`, `\` : (OS Path separator) When typing filepath, the path separator will
--   open a directory like `<cr>`.
-- • `<A-c>/c`: Create file/folder at current `path` (trailing path separator
--   creates folder)
-- • `<A-r>/r`: Rename multi-selected files/folders
-- • `<A-m>/m`: Move multi-selected files/folders to current `path`
-- • `<A-y>/y`: Copy (multi-)selected files/folders to current `path`
-- • `<A-d>/d`: Delete (multi-)selected files/folders
-- • `<C-o>/o`: Open file/folder with default system application
-- • `<C-g>/g`: Go to parent directory
-- • `<C-e>/e`: Go to home directory
-- • `<C-w>/w`: Go to current working directory (cwd)
-- • `<C-t>/t`: Change nvim's cwd to selected folder/file(parent)
-- • `<C-f>/f`: Toggle between file and folder browser
-- • `<C-h>/h`: Toggle hidden files/folders
-- • `<C-s>/s`: Toggle all entries ignoring `./` and `../`
-- • `<bs>/` : Goes to parent dir if prompt is empty, otherwise acts normally
