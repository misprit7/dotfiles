-- ANSI escape sequence highlighting (e.g. for bazel_wrapper build buffer)
-- https://github.com/0xferrous/ansi.nvim

return {
  '0xferrous/ansi.nvim',
  lazy = true,
  ft = { 'ansi', 'log' },  -- load when entering a buffer with ANSI output
  cmd = { 'AnsiEnable', 'AnsiDisable', 'AnsiToggle' },
  config = function()
    require('ansi').setup({
      auto_enable = true,
      filetypes = { 'log', 'ansi' },
      theme = 'terminal', -- use terminal colors; or 'gruvbox', 'dracula', etc.
    })
  end,
}
