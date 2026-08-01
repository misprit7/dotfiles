--- Spacemacs-style window navigation: <leader>w {h,j,k,l} to move, w d to close, w / and w - to split.
--- Load with: require('window_navigation')
--- Requires: mapleader set (e.g. vim.g.mapleader = ' ').
---
--- Window resize by percentage: <leader>w x [0-9] for width (100% or 10%-90%), <leader>w y [0-9] for height.
--- Only applies when there are multiple windows (splits) so other windows can fill the rest.

local function setup()
  local map = function(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.desc = opts.desc or ''
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  local leader_w = '<leader>w'

  -- Navigate: focus window in direction (like Spacemacs SPC w h/j/k/l)
  map('n', leader_w .. 'h', '<C-w>h', { desc = 'Window left' })
  map('n', leader_w .. 'j', '<C-w>j', { desc = 'Window down' })
  map('n', leader_w .. 'k', '<C-w>k', { desc = 'Window up' })
  map('n', leader_w .. 'l', '<C-w>l', { desc = 'Window right' })

  -- Delete/close current window
  map('n', leader_w .. 'd', '<C-w>c', { desc = 'Window delete (close)' })

  -- Split: vertical (/) and horizontal (-)
  map('n', leader_w .. '/', '<C-w>v', { desc = 'Window split vertical' })
  map('n', leader_w .. '-', '<C-w>s', { desc = 'Window split horizontal' })

  -- Resize by percentage (only when multiple windows exist)
  local function resize_width(pct)
    return function()
      if vim.fn.winnr('$') < 2 then
        vim.notify('Need multiple windows to resize (e.g. split first)', vim.log.levels.INFO)
        return
      end
      local cols = math.max(1, math.floor(vim.o.columns * pct / 100))
      vim.api.nvim_win_set_width(0, cols)
    end
  end
  local function resize_height(pct)
    return function()
      if vim.fn.winnr('$') < 2 then
        vim.notify('Need multiple windows to resize (e.g. split first)', vim.log.levels.INFO)
        return
      end
      local lines = math.max(1, math.floor((vim.o.lines - 1) * pct / 100))
      vim.api.nvim_win_set_height(0, lines)
    end
  end

  for n = 0, 9 do
    local pct = n == 0 and 100 or n * 10
    map('n', leader_w .. 'x' .. n, resize_width(pct), { desc = 'Window width ' .. pct .. '%' })
    map('n', leader_w .. 'y' .. n, resize_height(pct), { desc = 'Window height ' .. pct .. '%' })
  end
end

setup()

return {}
