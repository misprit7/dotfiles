--- Clean flow for Bazel: run bazel clean to remove output files.
--- Uses a real terminal buffer for proper colors and interactive output.
--- Depends on query module.

return function(query)
  local M = {}

  --- Run `bazel clean` in a terminal to remove build outputs.
  ---@param workspace_root string
  function M.run_clean(workspace_root)
    if not workspace_root or workspace_root == "" then
      vim.notify("build-wrapper[bazel]: no workspace root", vim.log.levels.ERROR)
      return
    end

    local saved_winid = vim.api.nvim_get_current_win()

    vim.cmd("botright new")
    local terminal_winid = vim.api.nvim_get_current_win()
    local terminal_bufnr = vim.api.nvim_get_current_buf()
    vim.bo[terminal_bufnr].buflisted = false

    local cmd = string.format(
      "cd %s && echo '=== Bazel clean ===' && bazel clean",
      vim.fn.shellescape(workspace_root)
    )

    vim.fn.termopen(cmd, {
      on_exit = function(_, code, _) end,
    })

    vim.api.nvim_set_current_win(saved_winid)
    vim.notify("build-wrapper[bazel]: running bazel clean", vim.log.levels.INFO)
  end

  --- Find workspace root and run bazel clean.
  function M.clean_current_package()
    local current = vim.api.nvim_buf_get_name(0)
    if current == "" then
      current = vim.loop.cwd()
    else
      current = vim.fn.fnamemodify(current, ":p:h")
    end

    local root = query.find_workspace_root(current)
    if not root then
      vim.notify("build-wrapper[bazel]: no Bazel workspace root (WORKSPACE or MODULE.bazel) found", vim.log.levels.ERROR)
      return
    end

    M.run_clean(root)
  end

  return M
end
