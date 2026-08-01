-- Pyright: use .venv found by walking upward from the open file's directory.
-- Call setup() from your LSP config to register the LspAttach handler.

local M = {}

--- Find .venv by walking upward from start_path (directory). Returns path to .venv or nil.
local function find_venv_upward(start_path)
  if not start_path or start_path == '' then return nil end
  local dir = vim.fn.fnamemodify(start_path, ':p')
  if dir:sub(-1) == '/' then dir = dir:sub(1, -2) end
  while dir and dir ~= '' and dir ~= '/' do
    local venv = dir .. '/.venv'
    if vim.fn.isdirectory(venv) == 1 then
      return venv
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  return nil
end

--- Return the .venv path and python path for the current buffer, or nil, nil.
function M.get_venv_for_buf(bufnr)
  bufnr = bufnr or 0
  local path = vim.api.nvim_buf_get_name(bufnr)
  if not path or path == '' then return nil, nil end
  local file_dir = vim.fn.fnamemodify(path, ':p:h')
  local venv = find_venv_upward(file_dir)
  if not venv then return nil, nil end
  local python = venv .. '/bin/python'
  if vim.fn.executable(python) ~= 1 then
    python = venv .. '/bin/python3'
  end
  return venv, (vim.fn.executable(python) == 1) and python or venv .. '/bin/python'
end

--- Register LspAttach handler that configures Pyright to use .venv when present.
function M.setup()
  vim.api.nvim_create_user_command('PyrightVenv', function()
    local venv, python = M.get_venv_for_buf(0)
    if venv then
      vim.notify(string.format('Pyright venv: %s\nPython: %s', venv, python or venv .. '/bin/python'), vim.log.levels.INFO)
    else
      vim.notify('No .venv found for this file (Pyright using default Python).', vim.log.levels.INFO)
    end
  end, { desc = 'Show which Python/venv Pyright is using for current buffer' })

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-venv-pyright', { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if not client or client.name ~= 'pyright' then return end

      local path = vim.api.nvim_buf_get_name(event.buf)
      if not path or path == '' then return end

      local file_dir = vim.fn.fnamemodify(path, ':p:h')
      local venv = find_venv_upward(file_dir)
      if not venv then return end

      local venv_path = vim.fn.fnamemodify(venv, ':h')
      local venv_name = vim.fn.fnamemodify(venv, ':t')
      client:notify('workspace/didChangeConfiguration', {
        settings = { python = { venvPath = venv_path, venv = venv_name } },
      })
    end,
  })
end

return M
