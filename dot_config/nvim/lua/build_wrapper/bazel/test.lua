--- Test flow: start_test, test_current_package.
--- Depends on output and query modules.

return function(output, query)
  local M = {}

  --- Run `bazel test` for the given targets; stream output to the test buffer.
  ---@param workspace_root string
  ---@param targets string[]
  function M.start_test(workspace_root, targets)
    if #targets == 0 then
      vim.notify("build-wrapper[bazel]: no test targets", vim.log.levels.ERROR)
      return
    end

    output.kill_oneoff_job()

    local bufnr, _ = output.ensure_test_window()
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.bo[bufnr].modifiable = false

    vim.schedule(function()
      pcall(function() require("ansi").enable(bufnr) end)
    end)

    local append = output.make_append_with_ansi(bufnr)
    local args = vim.list_extend({ "test", "--color=yes" }, targets)

    if vim.system then
      local job = vim.system(vim.list_extend({ "bazel" }, args), {
        cwd = workspace_root,
        stdout = function(_, d)
          vim.schedule(function() append(d) end)
        end,
        stderr = function(_, d)
          vim.schedule(function() append(d) end)
        end,
        on_exit = function()
          output.set_oneoff_job(nil)
        end,
      })
      output.set_oneoff_job(job)
    else
      local job_id = vim.fn.jobstart(vim.list_extend({ "bazel" }, args), {
        cwd = workspace_root,
        stdout_buffered = false,
        stderr_buffered = false,
        on_stdout = function(_, data, _)
          append(data)
        end,
        on_stderr = function(_, data, _)
          append(data)
        end,
        on_exit = function()
          output.set_oneoff_job(nil)
        end,
      })
      output.set_oneoff_job(job_id)
    end
  end

  --- Find workspace/package, query test targets, run bazel test.
  function M.test_current_package()
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

    local targets = query.query_test_targets(root, pkg)
    if not targets or #targets == 0 then
      vim.notify("build-wrapper[bazel]: no *_test target in package " .. pkg, vim.log.levels.ERROR)
      return
    end

    M.start_test(root, targets)
  end

  return M
end
