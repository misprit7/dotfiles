--- Build flow for NX: start_build, kill_build, build_current_package.
--- Uses a real terminal buffer for proper colors and interactive output.
--- Uses watchexec for reliable file watching (respects all .gitignore files automatically).
--- Depends on output and query modules.

return function(output, query, opts)
  local M = {}

  -- Track the terminal job for killing
  local terminal_job_id = nil
  local terminal_bufnr = nil
  local terminal_winid = nil
  local build_script_path = nil  -- temp script for watchexec callback, cleaned on exit

  --- Start NX build with file watching via watchexec.
  --- Cancels any existing build first.
  ---@param workspace_root string
  ---@param project string
  function M.start_build(workspace_root, project)
    if not project or project == "" then
      vim.notify("build-wrapper[nx]: no project to build", vim.log.levels.ERROR)
      return
    end

    -- Kill existing build/watch
    M.kill_build()

    local saved_winid = vim.api.nvim_get_current_win()

    -- Create terminal window
    vim.cmd("botright vnew")
    terminal_winid = vim.api.nvim_get_current_win()
    terminal_bufnr = vim.api.nvim_get_current_buf()
    vim.bo[terminal_bufnr].buflisted = false

    -- Write a helper script for watchexec to run on changes.
    -- watchexec sets WATCHEXEC_WRITTEN_PATH, WATCHEXEC_COMMON_PATH env vars.
    if build_script_path and vim.uv.fs_stat(build_script_path) then
      pcall(vim.uv.fs_unlink, build_script_path)
    end
    build_script_path = vim.fn.tempname() .. ".nx-build.sh"
    local script_path = build_script_path
    -- Ensure absolute path for cd (termopen may have different cwd)
    local root_abs = vim.fn.fnamemodify(workspace_root, ":p")
    root_abs = root_abs:gsub("/$", "")  -- strip trailing slash
    local nx_run = "npx nx"  -- uses local if in node_modules, else global
    local script = ([[#!/bin/sh
set -e
cd %s
clear
echo "=== Build at $(date +%%H:%%M:%%S) ==="
if [ -n "$WATCHEXEC_WRITTEN_PATH" ]; then
  echo "Changed: $WATCHEXEC_WRITTEN_PATH"
else
  echo "Initial build"
fi
echo ""
GRAPH=$(NX_DAEMON=false %s run %s:build --graph=stdout 2>/dev/null) || true
if echo "$GRAPH" | jq -e '.tasks.tasks' >/dev/null 2>&1; then
  echo "Building:"
  echo "$GRAPH" | jq -r '.tasks.tasks | keys | sort[]' | sed 's/[:-]build$//' | sed 's/^/  • /'
  echo ""
fi
exec env NX_DAEMON=false %s run %s:build --no-tui --color
]]):format(
      (root_abs:gsub("%%", "%%%%")),
      (nx_run:gsub("%%", "%%%%")),
      (project:gsub("%%", "%%%%")),
      (nx_run:gsub("%%", "%%%%")),
      (project:gsub("%%", "%%%%"))
    )
    local f = io.open(script_path, "w")
    if f then
      f:write(script)
      f:close()
      vim.uv.fs_chmod(script_path, 448)  -- 0700
    end

    -- Use watchexec for file watching.
    -- watchexec automatically respects all .gitignore files (including nested ones).
    -- --project-origin sets the root for gitignore discovery.
    -- -c clears screen before each run.
    -- --no-process-group allows ctrl-c to work properly in terminal.
    local cmd = string.format(
      [[cd %s && echo '=== Build watcher started for %s ===' && echo 'Watching for changes (watchexec)...' && echo '' && watchexec --project-origin %s -c --no-process-group -- %s]],
      vim.fn.shellescape(root_abs),
      project,
      vim.fn.shellescape(root_abs),
      vim.fn.shellescape(script_path)
    )

    terminal_job_id = vim.fn.termopen(cmd, {
      on_exit = function(_, code, _)
        terminal_job_id = nil
        if build_script_path and vim.uv.fs_stat(build_script_path) then
          pcall(vim.uv.fs_unlink, build_script_path)
          build_script_path = nil
        end
      end,
    })

    vim.api.nvim_set_current_win(saved_winid)
    vim.notify("build-wrapper[nx]: watching for changes (watchexec)", vim.log.levels.INFO)
  end

  --- Kill the current running build and stop watching.
  function M.kill_build()
    if terminal_job_id and vim.fn.jobwait({ terminal_job_id }, 0)[1] == -1 then
      pcall(vim.fn.jobstop, terminal_job_id)
      terminal_job_id = nil
    end

    -- Close terminal window
    if terminal_winid and vim.api.nvim_win_is_valid(terminal_winid) then
      vim.api.nvim_win_close(terminal_winid, true)
      terminal_winid = nil
    end
    terminal_bufnr = nil
    if build_script_path and vim.uv.fs_stat(build_script_path) then
      pcall(vim.uv.fs_unlink, build_script_path)
      build_script_path = nil
    end

    vim.notify("build-wrapper[nx]: build stopped", vim.log.levels.INFO)
  end

  --- Find workspace/project, show picker if needed, then start build.
  function M.build_current_package()
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
      -- Check if project has build target
      if query.has_target(root, project, "build") then
        M.start_build(root, project)
        return
      end
    end

    -- No project found or no build target, show picker
    local projects = query.query_projects(root)
    if not projects or #projects == 0 then
      vim.notify("build-wrapper[nx]: no projects found in workspace", vim.log.levels.ERROR)
      return
    end

    vim.ui.select(projects, {
      prompt = "Build NX project",
      format_item = function(item) return item end,
    }, function(choice)
      if choice then
        M.start_build(root, choice)
      end
    end)
  end

  return M
end
