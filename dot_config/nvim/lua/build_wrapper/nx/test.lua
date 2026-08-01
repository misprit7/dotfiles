--- Test flow for NX: start_test, test_current_package.
--- Uses a real terminal buffer for proper colors and interactive output.
--- Depends on output and query modules.

return function(output, query)
  local M = {}

  --- Run `nx test` for the given project in the shared one-off terminal.
  ---@param workspace_root string
  ---@param project string
  function M.start_test(workspace_root, project)
    if not project or project == "" then
      vim.notify("build-wrapper[nx]: no project to test", vim.log.levels.ERROR)
      return
    end

    local _, winid = output.open_oneoff_terminal()
    local saved_winid = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(winid)

    -- --no-tui disables NX 21's Terminal UI which auto-exits after 3 seconds
    local cmd = string.format(
      "cd %s && nx test %s --no-tui --color",
      vim.fn.shellescape(workspace_root),
      project
    )

    local job_id = vim.fn.termopen(cmd, {
      on_exit = function()
        output.set_oneoff_terminal_job(nil)
        vim.schedule(function()
          vim.cmd("checktime")
        end)
      end,
    })
    output.set_oneoff_terminal_job(job_id)
    vim.api.nvim_set_current_win(saved_winid)
  end

  --- Find workspace/project, run nx test.
  function M.test_current_package()
    local current = vim.api.nvim_buf_get_name(0)
    if current == "" then
      current = vim.loop.cwd()
    else
      current = vim.fn.fnamemodify(current, ":p:h")
    end

    local root = query.find_workspace_root(current)
    if not root then
      vim.notify("build-wrapper[nx]: no NX workspace root (nx.json) found", vim.log.levels.ERROR)
      return
    end

    local project = query.find_current_project(root, current)
    if project then
      -- Check if project has test target
      if query.has_target(root, project, "test") then
        M.start_test(root, project)
        return
      end
    end

    -- No project found or no test target, show picker
    local projects = query.query_projects(root)
    if not projects or #projects == 0 then
      vim.notify("build-wrapper[nx]: no projects found in workspace", vim.log.levels.ERROR)
      return
    end

    vim.ui.select(projects, {
      prompt = "Test NX project",
      format_item = function(item) return item end,
    }, function(choice)
      if choice then
        M.start_test(root, choice)
      end
    end)
  end

  return M
end
