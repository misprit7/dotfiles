--- Run flow: run a single binary, run_current_package (with binary picker when multiple).
--- Depends on output and query modules.

return function(output, query)
  local M = {}

  --- Run a single binary target: opens run window, clears buffer, streams bazel run output.
  ---@param root string workspace root
  ---@param target string label e.g. "//pkg:main"
  local function run_binary(root, target)
    output.kill_oneoff_job()

    local bufnr, _ = output.ensure_run_window()
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.bo[bufnr].modifiable = false

    vim.schedule(function()
      pcall(function() require("ansi").enable(bufnr) end)
    end)

    local append = output.make_append_with_ansi(bufnr)

    if vim.system then
      local job = vim.system({ "bazel", "run", "--color=yes", target }, {
        cwd = root,
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
      local job_id = vim.fn.jobstart({ "bazel", "run", "--color=yes", target }, {
        cwd = root,
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

  --- Run the executable target: finds *_binary in the package.
  --- If a binary target sources the current file, runs it directly; otherwise shows a picker.
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
      vim.notify("build-wrapper[bazel]: no Bazel workspace root (WORKSPACE or MODULE.bazel) found", vim.log.levels.ERROR)
      return
    end

    local pkg = query.find_current_package(root, current)
    if not pkg then
      vim.notify("build-wrapper[bazel]: no BUILD/BUILD.bazel found for current file", vim.log.levels.ERROR)
      return
    end

    local binaries = query.query_binary_targets(root, pkg)
    if not binaries or #binaries == 0 then
      vim.notify("build-wrapper[bazel]: no *_binary target in package " .. pkg, vim.log.levels.ERROR)
      return
    end

    -- If a binary target sources the current file, run it directly
    local filename = vim.fn.fnamemodify(bufname, ":t")
    if filename and filename ~= "" then
      local matching = query.query_binary_for_file(root, pkg, filename)
      if matching and #matching == 1 then
        run_binary(root, matching[1])
        return
      end
    end

    -- Single binary in package: run it
    if #binaries == 1 then
      run_binary(root, binaries[1])
      return
    end

    -- Multiple binaries: show picker with sensible default
    local default = binaries[1]
    local file_stem = vim.fn.fnamemodify(bufname, ":t:r")
    if file_stem and file_stem ~= "" then
      for _, label in ipairs(binaries) do
        local name = label:match(":([^:]+)$")
        if name == file_stem then
          default = label
          break
        end
      end
    end

    vim.ui.select(binaries, {
      prompt = "Run binary",
      format_item = function(item) return item end,
      default = default,
    }, function(choice)
      if choice then
        run_binary(root, choice)
      end
    end)
  end

  return M
end
