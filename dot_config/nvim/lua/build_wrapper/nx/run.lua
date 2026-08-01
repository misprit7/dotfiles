--- Run/serve flow for NX: run_current_package.
--- Uses a real terminal buffer for proper colors and interactive output.
--- Depends on output and query modules.

return function(output, query)
  local M = {}

  --- Run NX serve/run for a project in the shared one-off terminal.
  ---@param root string workspace root
  ---@param project string project name
  ---@param target string target name (serve, start, dev, run-rust, etc.)
  local function run_project(root, project, target)
    local _, winid = output.open_oneoff_terminal()
    local saved_winid = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(winid)

    -- Run the command: nx run <project>:<target> (npx prefers local node_modules)
    local root_abs = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
    local cmd = string.format(
      "cd %s && npx nx run %s:%s --no-tui --color",
      vim.fn.shellescape(root_abs),
      project,
      target
    )

    local job_id = vim.fn.termopen(cmd, {
      on_exit = function()
        output.set_oneoff_terminal_job(nil)
      end,
    })
    output.set_oneoff_terminal_job(job_id)
    vim.api.nvim_set_current_win(saved_winid)
  end

  --- Run an NX target. Shows all targets for current project, or all targets across workspace.
  function M.run_current_package()
    local bufname = vim.api.nvim_buf_get_name(0)
    local current = bufname
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
      -- Show all targets for current project
      local targets = query.query_project_targets(root, project)
      if not targets or #targets == 0 then
        vim.notify("build-wrapper[nx]: no targets found for " .. project, vim.log.levels.ERROR)
        return
      end
      if #targets == 1 then
        run_project(root, project, targets[1])
        return
      end
      vim.ui.select(targets, {
        prompt = "Run NX target for " .. project,
        format_item = function(item) return item end,
      }, function(choice)
        if choice then
          run_project(root, project, choice)
        end
      end)
      return
    end

    -- No project context: show all targets from all projects
    local projects = query.query_projects(root)
    if not projects or #projects == 0 then
      vim.notify("build-wrapper[nx]: no projects found", vim.log.levels.ERROR)
      return
    end

    local choices = {}
    for _, proj in ipairs(projects) do
      local targets = query.query_project_targets(root, proj)
      if targets then
        for _, t in ipairs(targets) do
          table.insert(choices, { project = proj, target = t })
        end
      end
    end

    if #choices == 0 then
      vim.notify("build-wrapper[nx]: no targets found in workspace", vim.log.levels.ERROR)
      return
    end

    if #choices == 1 then
      run_project(root, choices[1].project, choices[1].target)
      return
    end

    vim.ui.select(choices, {
      prompt = "Run NX target",
      format_item = function(item) return item.project .. " › " .. item.target end,
    }, function(choice)
      if choice then
        run_project(root, choice.project, choice.target)
      end
    end)
  end

  return M
end
