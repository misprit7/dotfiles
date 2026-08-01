--- Query workspace, package, and Bazel targets (no UI state).
--- Used by build, run, and test flows.

local M = {}

--- Find Bazel workspace root by searching upward for WORKSPACE or MODULE.bazel.
---@param start_path string Directory to start from (e.g. current file's directory).
---@return string|nil workspace_root Absolute path, or nil if not found.
function M.find_workspace_root(start_path)
  if not start_path or start_path == "" then
    start_path = vim.loop.cwd()
  end
  local found = vim.fs.find({ "WORKSPACE", "MODULE.bazel" }, {
    upward = true,
    path = start_path,
  })
  if not found or #found == 0 then
    return nil
  end
  return vim.fn.fnamemodify(found[1], ":h")
end

--- Find the Bazel package containing the current buffer (nearest BUILD/BUILD.bazel upward).
---@param workspace_root string Absolute path to workspace root.
---@param current_path string Absolute path to current file (or its directory).
---@return string|nil package_label Label like "//trader/sim:*", or nil if not found.
function M.find_current_package(workspace_root, current_path)
  local dir = vim.fn.fnamemodify(current_path, ":p")
  if dir:sub(-1) == "/" then
    dir = dir:sub(1, -2)
  end
  local found = vim.fs.find({ "BUILD", "BUILD.bazel" }, {
    upward = true,
    path = dir,
  })
  if not found or #found == 0 then
    return nil
  end
  local package_dir = vim.fn.fnamemodify(found[1], ":h")
  local root = workspace_root:gsub("/$", "")
  local root_esc = (root:gsub("%%", "%%%%"):gsub("%-", "%%-"):gsub("%.", "%%."):gsub("%+", "%%+"):gsub("%*", "%%*"):gsub("%?", "%%?"):gsub("%[", "%%["):gsub("%]", "%%]"):gsub("^%^", "%%^"):gsub("%$", "%%$"))
  local rel = package_dir:gsub("^" .. root_esc .. "/?", ""):gsub("/$", "")
  local label = (rel == "" or rel == ".") and "//:*" or ("//" .. rel .. ":*")
  return label
end

--- Run bazel query and return lines (excluding "Loading...").
---@param workspace_root string cwd for the command.
---@param query_string string e.g. 'kind(".*_binary", //pkg:*)'
---@return string[]|nil targets List of lines (labels), or nil on error.
local function run_query(workspace_root, query_string)
  local raw = nil
  if vim.system then
    local result = vim.system(
      { "bazel", "query", query_string },
      { cwd = workspace_root, stdout = true, stderr = true }
    ):wait()
    if not result or result.code ~= 0 then
      return nil
    end
    raw = (result.stdout or "") .. (result.stderr or "")
  else
    local chunks = {}
    local job_id = vim.fn.jobstart({ "bazel", "query", query_string }, {
      cwd = workspace_root,
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then table.insert(chunks, line) end
          end
        end
      end,
      on_stderr = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then table.insert(chunks, line) end
          end
        end
      end,
    })
    if job_id <= 0 then
      return nil
    end
    vim.fn.jobwait({ job_id })
    raw = table.concat(chunks, "\n")
  end

  local targets = {}
  for line in (raw or ""):gmatch("[^\r\n]+") do
    line = line:match("^%s*(.-)%s*$") or line
    if line ~= "" and not line:match("^Loading") then
      table.insert(targets, line)
    end
  end
  return targets
end

--- Run `bazel query` for buildable targets (*_binary, *_library, *_test).
---@param workspace_root string cwd for the command.
---@param package_label string e.g. "//trader/sim:*"
---@return string[]|nil targets List of labels, or nil on error.
function M.query_targets(workspace_root, package_label)
  local query = string.format(
    'kind(".*_binary", %s) + kind(".*_library", %s) + kind(".*_test", %s)',
    package_label, package_label, package_label
  )
  return run_query(workspace_root, query)
end

--- Run `bazel query` for runnable (*_binary) targets only.
---@param workspace_root string cwd for the command.
---@param package_label string e.g. "//trader/sim:*"
---@return string[]|nil targets List of labels, or nil on error.
function M.query_binary_targets(workspace_root, package_label)
  local query = string.format('kind(".*_binary", %s)', package_label)
  return run_query(workspace_root, query)
end

--- Run `bazel query` for test targets (*_test) only.
---@param workspace_root string cwd for the command.
---@param package_label string e.g. "//trader/sim:*"
---@return string[]|nil targets List of labels, or nil on error.
function M.query_test_targets(workspace_root, package_label)
  local query = string.format('kind(".*_test", %s)', package_label)
  return run_query(workspace_root, query)
end

--- Find binary targets that have the given file in their srcs attribute.
---@param workspace_root string cwd for the command.
---@param package_label string e.g. "//trader/sim:*"
---@param filename string basename of the file (e.g. "main.cc")
---@return string[]|nil targets List of labels, or nil on error.
function M.query_binary_for_file(workspace_root, package_label, filename)
  local query = string.format('kind(".*_binary", attr(srcs, "%s", %s))', filename, package_label)
  return run_query(workspace_root, query)
end

return M
