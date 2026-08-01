-- Enable treesitter syntax highlighting for CUE files (only if cue parser is installed)
local ok = pcall(vim.treesitter.start)
if not ok then
  -- Parser not installed; treesitter highlighting unavailable
end
