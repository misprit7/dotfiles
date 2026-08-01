---@brief [[
--- build-wrapper: Unified build plugin supporting Bazel and NX monorepos.
--- Auto-detects the build system based on workspace markers:
---   - Bazel: WORKSPACE or MODULE.bazel
---   - NX: nx.json
---
--- Keymaps: <leader>bb build, <leader>br run, <leader>bt test, <leader>bk kill, <leader>bc clean.
--- Config: require('build_wrapper').setup({ quickfix = true })
---@brief ]]

local M = {}

-- Options (set via M.setup); merged with defaults.
local opts = {
  quickfix = true,
}

--- Set plugin options. Call before or after require; options are merged with defaults.
---@param user_opts table|nil { quickfix = boolean }
function M.setup(user_opts)
  if user_opts then
    for k, v in pairs(user_opts) do
      opts[k] = v
    end
  end
end

-- Shared output module
local output = require("build_wrapper.output")

-- Bazel modules
local bazel_query = require("build_wrapper.bazel.query")
local bazel_build = require("build_wrapper.bazel.build")(output, bazel_query, opts)
local bazel_run = require("build_wrapper.bazel.run")(output, bazel_query)
local bazel_test = require("build_wrapper.bazel.test")(output, bazel_query)
local bazel_clean = require("build_wrapper.bazel.clean")(bazel_query)

-- NX modules
local nx_query = require("build_wrapper.nx.query")
local nx_build = require("build_wrapper.nx.build")(output, nx_query, opts)
local nx_run = require("build_wrapper.nx.run")(output, nx_query)
local nx_test = require("build_wrapper.nx.test")(output, nx_query)
local nx_clean = require("build_wrapper.nx.clean")(nx_query)

--- Detect the build system for the current file/directory.
--- Returns "bazel", "nx", or nil if no build system detected.
---@param start_path string|nil Directory to start from.
---@return string|nil build_system "bazel", "nx", or nil
function M.detect_build_system(start_path)
  if not start_path or start_path == "" then
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= "" then
      start_path = vim.fn.fnamemodify(bufname, ":p:h")
    else
      start_path = vim.loop.cwd()
    end
  end

  -- Check for Bazel first (WORKSPACE or MODULE.bazel)
  local bazel_root = bazel_query.find_workspace_root(start_path)
  local nx_root = nx_query.find_workspace_root(start_path)

  if bazel_root and nx_root then
    -- Both detected, prefer the one with shorter path (more specific/nested)
    if #bazel_root >= #nx_root then
      return "bazel"
    else
      return "nx"
    end
  elseif bazel_root then
    return "bazel"
  elseif nx_root then
    return "nx"
  end

  return nil
end

-- Public API: re-export query functions
M.bazel = {
  find_workspace_root = bazel_query.find_workspace_root,
  find_current_package = bazel_query.find_current_package,
  query_targets = bazel_query.query_targets,
  query_binary_targets = bazel_query.query_binary_targets,
  query_binary_for_file = bazel_query.query_binary_for_file,
  query_test_targets = bazel_query.query_test_targets,
}

M.nx = {
  find_workspace_root = nx_query.find_workspace_root,
  find_current_project = nx_query.find_current_project,
  query_projects = nx_query.query_projects,
  query_project_targets = nx_query.query_project_targets,
  has_target = nx_query.has_target,
}

--- Build current package/project (auto-detects build system).
function M.build_current_package()
  local build_system = M.detect_build_system()
  if build_system == "bazel" then
    bazel_build.build_current_package()
  elseif build_system == "nx" then
    nx_build.build_current_package()
  else
    vim.notify("build-wrapper: no build system detected (Bazel or NX)", vim.log.levels.ERROR)
  end
end

--- Run current package/project (auto-detects build system).
function M.run_current_package()
  local build_system = M.detect_build_system()
  if build_system == "bazel" then
    bazel_run.run_current_package()
  elseif build_system == "nx" then
    nx_run.run_current_package()
  else
    vim.notify("build-wrapper: no build system detected (Bazel or NX)", vim.log.levels.ERROR)
  end
end

--- Test current package/project (auto-detects build system).
function M.test_current_package()
  local build_system = M.detect_build_system()
  if build_system == "bazel" then
    bazel_test.test_current_package()
  elseif build_system == "nx" then
    nx_test.test_current_package()
  else
    vim.notify("build-wrapper: no build system detected (Bazel or NX)", vim.log.levels.ERROR)
  end
end

--- Clean build outputs (auto-detects build system).
function M.clean_current_package()
  local build_system = M.detect_build_system()
  if build_system == "bazel" then
    bazel_clean.clean_current_package()
  elseif build_system == "nx" then
    nx_clean.clean_current_package()
  else
    vim.notify("build-wrapper: no build system detected (Bazel or NX)", vim.log.levels.ERROR)
  end
end

--- Kill the current running build (works for both Bazel and NX).
function M.kill_build()
  local running_job = output.get_running_job()
  if running_job then
    if type(running_job) == "number" then
      pcall(vim.fn.jobstop, running_job)
    elseif running_job.kill then
      pcall(running_job.kill, running_job)
    end
    output.set_running_job(nil)
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

  vim.notify("build-wrapper: build killed", vim.log.levels.INFO)
end

-- Direct access to backend modules for advanced use
M.start_bazel_build = bazel_build.start_build
M.start_nx_build = nx_build.start_build
M.start_bazel_test = bazel_test.start_test
M.start_nx_test = nx_test.start_test

--- Register <leader>b keymaps and :BuildTest command.
local function setup_keymaps()
  vim.keymap.set("n", "<leader>bb", function()
    M.build_current_package()
  end, { desc = "[B]uild current package" })
  vim.keymap.set("n", "<leader>br", function()
    M.run_current_package()
  end, { desc = "[B]uild [r]un executable" })
  vim.keymap.set("n", "<leader>bt", function()
    M.test_current_package()
  end, { desc = "[B]uild [t]est current package" })
  vim.keymap.set("n", "<leader>bk", function()
    M.kill_build()
  end, { desc = "[B]uild [k]ill" })
  vim.keymap.set("n", "<leader>bc", function()
    M.clean_current_package()
  end, { desc = "[B]uild [c]lean" })
  vim.api.nvim_create_user_command("BuildTest", function()
    M.test_current_package()
  end, { desc = "Run test for current package (Bazel or NX)" })
end

setup_keymaps()

return M
