--- Query NX workspace and project information.
--- Used by build, run, and test flows.

local M = {}

--- Find NX workspace root by searching upward for nx.json.
---@param start_path string Directory to start from (e.g. current file's directory).
---@return string|nil workspace_root Absolute path, or nil if not found.
function M.find_workspace_root(start_path)
  if not start_path or start_path == "" then
    start_path = vim.loop.cwd()
  end
  local found = vim.fs.find({ "nx.json" }, {
    upward = true,
    path = start_path,
  })
  if not found or #found == 0 then
    return nil
  end
  -- :p:h gives absolute parent dir (ensures cwd works in subprocesses)
  return vim.fn.fnamemodify(found[1], ":p:h"):gsub("/$", "")
end

--- Find the NX project for the current file by looking at project.json or package.json.
---@param workspace_root string Absolute path to workspace root.
---@param current_path string Absolute path to current file (or its directory).
---@return string|nil project_name The NX project name, or nil if not found.
function M.find_current_project(workspace_root, current_path)
  local dir = vim.fn.fnamemodify(current_path, ":p")
  if dir:sub(-1) == "/" then
    dir = dir:sub(1, -2)
  end

  -- Search upward for project.json (NX project marker)
  local found = vim.fs.find({ "project.json" }, {
    upward = true,
    path = dir,
    stop = workspace_root,
  })

  if found and #found > 0 then
    local project_json = found[1]
    local content = vim.fn.readfile(project_json)
    if content and #content > 0 then
      local ok, json = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and json and json.name then
        return json.name
      end
    end
  end

  -- Fallback: look for package.json with name field
  found = vim.fs.find({ "package.json" }, {
    upward = true,
    path = dir,
    stop = workspace_root,
  })

  if found and #found > 0 then
    local package_json = found[1]
    local content = vim.fn.readfile(package_json)
    if content and #content > 0 then
      local ok, json = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and json and json.name then
        return json.name
      end
    end
  end

  return nil
end

--- Build flat command array: nx_cmd + args (avoids deprecated vim.tbl_flatten)
local function nx_args(nx, ...)
  local args = { ... }
  local cmd = {}
  for _, v in ipairs(nx) do cmd[#cmd + 1] = v end
  for _, v in ipairs(args) do cmd[#cmd + 1] = v end
  return cmd
end

--- Get list of all projects in the NX workspace.
---@param workspace_root string cwd for the command.
---@return string[]|nil projects List of project names, or nil on error.
function M.query_projects(workspace_root)
  local nx = { "npx", "nx" }
  -- NX_DAEMON=false: bypass daemon to avoid stale project graph (main disappearing until nx reset)
  local env = vim.tbl_extend("force", vim.fn.environ() or {}, { NX_DAEMON = "false" })
  local result
  if vim.system then
    result = vim.system(
      nx_args(nx, "show", "projects"),
      { cwd = workspace_root, stdout = true, stderr = true, env = env }
    ):wait()
    if not result or result.code ~= 0 then
      return nil
    end
  else
    local chunks = {}
    local job_id = vim.fn.jobstart(nx_args(nx, "show", "projects"), {
      cwd = workspace_root,
      env = env,
      stdout_buffered = true,
      on_stdout = function(_, data)
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
    result = { stdout = table.concat(chunks, "\n") }
  end

  local projects = {}
  for line in (result.stdout or ""):gmatch("[^\r\n]+") do
    line = line:match("^%s*(.-)%s*$") or line
    if line ~= "" then
      table.insert(projects, line)
    end
  end
  return projects
end

--- Get available targets for a specific project.
---@param workspace_root string cwd for the command.
---@param project_name string The NX project name.
---@return string[]|nil targets List of target names (build, test, serve, etc.), or nil on error.
function M.query_project_targets(workspace_root, project_name)
  -- Use vim.fn.system (runs via shell) so we inherit shell PATH (nvm, etc.).
  -- vim.system/jobstart run directly without shell and may lack node in PATH.
  local root = vim.fn.fnamemodify(workspace_root, ":p"):gsub("/$", "")
  local cmd = string.format(
    "cd %s && NX_DAEMON=false npx nx show project %s --json --no-color 2>/dev/null",
    vim.fn.shellescape(root),
    vim.fn.shellescape(project_name)
  )
  local stdout = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 or not stdout or stdout == "" then
    return nil
  end

  local ok, json = pcall(vim.json.decode, stdout)
  if not ok or not json or not json.targets then
    return nil
  end

  local targets = {}
  for target_name, _ in pairs(json.targets) do
    table.insert(targets, target_name)
  end
  table.sort(targets)
  return targets
end

--- Check if a project has a specific target.
---@param workspace_root string cwd for the command.
---@param project_name string The NX project name.
---@param target_name string The target to check for (e.g., "build", "test", "serve").
---@return boolean
function M.has_target(workspace_root, project_name, target_name)
  local targets = M.query_project_targets(workspace_root, project_name)
  if not targets then
    return false
  end
  for _, t in ipairs(targets) do
    if t == target_name then
      return true
    end
  end
  return false
end

return M
