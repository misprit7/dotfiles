--- Build flow: start_build, kill_build, build_current_package (with target picker).
--- Depends on output and query modules; receives opts from init.

--- Targets that have no workspace source deps; iBazel "Didn't find any files to watch" is expected and filtered.
local NO_WATCH_TARGETS = { "//:refresh_compile_commands" }

return function(output, query, opts)
  local M = {}

  --- Start ibazel build asynchronously; stream stdout/stderr into the build buffer.
  --- Cancels any existing build first.
  ---@param workspace_root string
  ---@param targets string[]
  function M.start_build(workspace_root, targets)
    if #targets == 0 then
      vim.notify("build-wrapper[bazel]: no targets to build", vim.log.levels.ERROR)
      return
    end

    local running_job = output.get_watcher_job()
    if running_job then
      if type(running_job) == "number" then
        pcall(vim.fn.jobstop, running_job)
      elseif running_job.kill then
        pcall(running_job.kill, running_job)
      end
      output.set_watcher_job(nil)
    end

    local bufnr, _ = output.ensure_build_window()
    if opts.quickfix then
      vim.fn.setqflist({}, "r")
    end
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.bo[bufnr].modifiable = false

    vim.schedule(function()
      pcall(function() require("ansi").enable(bufnr) end)
    end)

    local function data_contains_new_run(d)
      if type(d) == "string" then return d:find("Building //") ~= nil end
      if type(d) == "table" then
        for _, line in ipairs(d) do
          if line and type(line) == "string" and line:find("Building //") then return true end
        end
      end
      return false
    end
    local append = output.make_append_with_ansi(bufnr, {
      clear_if = data_contains_new_run,
      filter_sifting = true,
      filter_no_watch_for_targets = NO_WATCH_TARGETS,
      current_targets = targets,
    })

    local args = vim.list_extend({ "build" }, targets)

    local function try_populate_quickfix(exit_code)
      if not opts.quickfix or exit_code == 0 then return end
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local text = table.concat(lines, "\n")
      local qf_items = output.parse_quickfix_lines(text, workspace_root)
      if #qf_items > 0 then
        vim.fn.setqflist(qf_items, "r")
        vim.schedule(function()
          vim.cmd("copen")
        end)
      end
    end

    if vim.system then
      local cmd = vim.list_extend({ "ibazel" }, args)
      local job = vim.system(cmd, {
        cwd = workspace_root,
        stdout = function(_, d)
          vim.schedule(function() append(d) end)
        end,
        stderr = function(_, d)
          vim.schedule(function() append(d) end)
        end,
        on_exit = function(a, b)
          output.set_watcher_job(nil)
          local code = (type(a) == "number") and a or (type(b) == "number") and b or 1
          vim.schedule(function()
            try_populate_quickfix(code)
          end)
        end,
      })
      output.set_watcher_job(job)
      return
    end

    local job_id = vim.fn.jobstart({ "ibazel", unpack(args) }, {
      cwd = workspace_root,
      stdout_buffered = false,
      stderr_buffered = false,
      on_stdout = function(_, data, _)
        append(data)
      end,
      on_stderr = function(_, data, _)
        append(data)
      end,
      on_exit = function(_, code, _)
        output.set_watcher_job(nil)
        vim.schedule(function()
          try_populate_quickfix(code or 1)
        end)
      end,
    })
    if job_id <= 0 then
      vim.notify("build-wrapper[bazel]: failed to start ibazel job", vim.log.levels.ERROR)
      return
    end
    output.set_watcher_job(job_id)
  end

  --- Kill the current running build (ibazel job), if any.
  function M.kill_build()
    local running_job = output.get_watcher_job()
    if running_job then
      if type(running_job) == "number" then
        pcall(vim.fn.jobstop, running_job)
      elseif running_job.kill then
        pcall(running_job.kill, running_job)
      end
      output.set_watcher_job(nil)
    end

    local build_buf = vim.fn.bufnr(output.BUFFER_NAME, false)
    if build_buf >= 0 then
      for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(winid) then
          local win_buf = vim.api.nvim_win_get_buf(winid)
          if win_buf == build_buf then
            local blank = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_win_set_buf(winid, blank)
          end
        end
      end
    end

    vim.notify("build-wrapper[bazel]: build killed", vim.log.levels.INFO)
  end

  --- Find workspace/package, query targets, show picker, then start watch build.
  function M.build_current_package()
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

    local pkg = query.find_current_package(root, current)
    if not pkg then
      vim.notify("build-wrapper[bazel]: no BUILD/BUILD.bazel found for current file", vim.log.levels.ERROR)
      return
    end

    local targets = query.query_targets(root, pkg)
    if not targets or #targets == 0 then
      vim.notify("build-wrapper[bazel]: no targets in package " .. pkg, vim.log.levels.ERROR)
      return
    end

    if #targets == 1 then
      M.start_build(root, targets)
      return
    end

    local items = vim.list_extend({ "Build all" }, targets)
    vim.ui.select(items, {
      prompt = "Build target(s)",
      format_item = function(item) return item end,
    }, function(choice)
      if not choice then return end
      if choice == "Build all" then
        M.start_build(root, targets)
      else
        M.start_build(root, { choice })
      end
    end)
  end

  return M
end
