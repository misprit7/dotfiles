-- Your plugins: add specs here or in other files in this directory.
-- Lazy.nvim imports this via { import = 'plugins' } in init.lua.
return {
  require 'plugins.lazygit',
  require 'plugins.ansi',
  require 'plugins.copilot',
  require 'plugins.nx',
}
