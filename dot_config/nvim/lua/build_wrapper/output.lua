--- Output buffers, windows, and streaming helpers (build/run/test).
--- Holds buffer/window state and two separate job slots:
---   watcher_job     — long-running build watcher (ibazel / watchexec). Only build modules touch this.
---   oneoff_job      — short-lived one-off commands (bazel test/run). Shared across all one-off modules.
--- NX modules use terminal buffers and manage window state via open_oneoff_terminal / kill_oneoff_terminal.

local M = {}

-- State: output buffers
local build_bufnr = nil
local build_winid = nil
local run_bufnr = nil
local run_winid = nil
local test_bufnr = nil
local test_winid = nil

-- Watcher job slot (bazel/build ibazel — never touched by one-off modules)
local watcher_job = nil

-- One-off job slot (bazel/test, bazel/run — never touched by watcher modules)
local oneoff_job = nil

-- Shared one-off terminal slot (nx/test, nx/run — never touched by nx/build)
local oneoff_terminal = { job_id = nil, bufnr = nil, winid = nil }

M.BUFFER_NAME = "build_wrapper_build"
local RUN_BUFFER_NAME = "build_wrapper_run"
local TEST_BUFFER_NAME = "build_wrapper_test"

-- Watcher job accessors (for bazel/build)
function M.get_watcher_job() return watcher_job end
function M.set_watcher_job(job) watcher_job = job end

-- One-off job accessors (for bazel/test, bazel/run)
function M.get_oneoff_job() return oneoff_job end
function M.set_oneoff_job(job) oneoff_job = job end

function M.kill_oneoff_job()
  if oneoff_job then
    if type(oneoff_job) == "number" then
      pcall(vim.fn.jobstop, oneoff_job)
    elseif oneoff_job.kill then
      pcall(oneoff_job.kill, oneoff_job)
    end
    oneoff_job = nil
  end
end

--- Kill any running one-off terminal job and close its window (for nx/test, nx/run).
function M.kill_oneoff_terminal()
  if oneoff_terminal.job_id and vim.fn.jobwait({ oneoff_terminal.job_id }, 0)[1] == -1 then
    pcall(vim.fn.jobstop, oneoff_terminal.job_id)
  end
  oneoff_terminal.job_id = nil
  if oneoff_terminal.winid and vim.api.nvim_win_is_valid(oneoff_terminal.winid) then
    vim.api.nvim_win_close(oneoff_terminal.winid, true)
  end
  oneoff_terminal.winid = nil
  oneoff_terminal.bufnr = nil
end

--- Open the shared one-off terminal, killing any existing one first.
--- Returns bufnr, winid. Focus is restored to the caller's window.
---@return number bufnr
---@return number winid
function M.open_oneoff_terminal()
  M.kill_oneoff_terminal()
  local saved_winid = vim.api.nvim_get_current_win()
  vim.cmd("botright new")
  oneoff_terminal.winid = vim.api.nvim_get_current_win()
  oneoff_terminal.bufnr = vim.api.nvim_get_current_buf()
  vim.bo[oneoff_terminal.bufnr].buflisted = false
  vim.api.nvim_set_current_win(saved_winid)
  return oneoff_terminal.bufnr, oneoff_terminal.winid
end

--- Record the termopen() job ID for the one-off terminal.
---@param job_id number
function M.set_oneoff_terminal_job(job_id)
  oneoff_terminal.job_id = job_id
end

--- Ensure an output buffer exists and is shown in a split.
---@param buffer_name string Unique buffer name.
---@param split string "right" (vsplit) or "down" (horizontal split).
---@param keep_focus boolean If true, restore focus to the window that was current before opening.
---@param state table { bufnr, winid } to reuse; updated by this function.
---@return number bufnr
---@return number|nil winid
local function ensure_output_window(buffer_name, split, keep_focus, state)
  local existing = vim.fn.bufnr(buffer_name, true)
  if existing > 0 and vim.api.nvim_buf_is_valid(existing) then
    state.bufnr = existing
  else
    state.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(state.bufnr, buffer_name)
  end

  vim.api.nvim_buf_set_option(state.bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(state.bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(state.bufnr, "swapfile", false)
  vim.bo[state.bufnr].buflisted = false
  vim.bo[state.bufnr].modifiable = true
  vim.bo[state.bufnr].filetype = "ansi"

  local need_open = not state.winid or not vim.api.nvim_win_is_valid(state.winid)
  local saved_winid = nil
  if need_open and keep_focus then
    saved_winid = vim.api.nvim_get_current_win()
  end

  if need_open then
    if split == "down" then
      vim.cmd("botright split")
    else
      vim.cmd("botright vsplit")
    end
    state.winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.winid, state.bufnr)
    if keep_focus and saved_winid and vim.api.nvim_win_is_valid(saved_winid) then
      vim.api.nvim_set_current_win(saved_winid)
    end
  else
    vim.api.nvim_win_set_buf(state.winid, state.bufnr)
    if not keep_focus then
      vim.api.nvim_set_current_win(state.winid)
    end
  end

  return state.bufnr, state.winid
end

function M.ensure_build_window()
  local state = { bufnr = build_bufnr, winid = build_winid }
  ensure_output_window(M.BUFFER_NAME, "right", true, state)
  build_bufnr = state.bufnr
  build_winid = state.winid
  return build_bufnr, build_winid
end

function M.ensure_run_window()
  local state = { bufnr = run_bufnr, winid = run_winid }
  ensure_output_window(RUN_BUFFER_NAME, "down", true, state)
  run_bufnr = state.bufnr
  run_winid = state.winid
  return run_bufnr, run_winid
end

function M.ensure_test_window()
  local state = { bufnr = test_bufnr, winid = test_winid }
  ensure_output_window(TEST_BUFFER_NAME, "down", true, state)
  test_bufnr = state.bufnr
  test_winid = state.winid
  return test_bufnr, test_winid
end

--- Parse compiler-style lines (file:line:col: msg and file:line: msg) from text.
---@param text string Full output text.
---@param workspace_root string Absolute path to workspace.
---@return table[] qf_items List of setqflist items: { filename, lnum, col?, text }.
function M.parse_quickfix_lines(text, workspace_root)
  local items = {}
  local seen = {}
  for line in (text or ""):gmatch("[^\r\n]+") do
    local f, l, c, m = line:match("^(.+):(%d+):(%d+): (.+)$")
    if f and l and m then
      local path = f
      if path:sub(1, 1) ~= "/" and path:sub(2, 2) ~= ":" then
        path = workspace_root .. "/" .. path
      end
      path = vim.fn.fnamemodify(path, ":p")
      local key = path .. ":" .. l .. ":" .. (c or "0")
      if not seen[key] then
        seen[key] = true
        table.insert(items, { filename = path, lnum = tonumber(l), col = tonumber(c), text = m })
      end
    else
      f, l, m = line:match("^(.+):(%d+): (.+)$")
      if f and l and m then
        local path = f
        if path:sub(1, 1) ~= "/" and path:sub(2, 2) ~= ":" then
          path = workspace_root .. "/" .. path
        end
        path = vim.fn.fnamemodify(path, ":p")
        local key = path .. ":" .. l
        if not seen[key] then
          seen[key] = true
          table.insert(items, { filename = path, lnum = tonumber(l), text = m })
        end
      end
    end
  end
  return items
end

---@param lines string|string[]
---@return string[]
local function normalize_to_lines(lines)
  local result = {}
  if type(lines) == "string" then
    for _, line in ipairs(vim.split(lines, "\n", { plain = true })) do
      result[#result + 1] = line
    end
  elseif type(lines) == "table" then
    for _, item in ipairs(lines) do
      if type(item) == "string" then
        for _, line in ipairs(vim.split(item, "\n", { plain = true })) do
          result[#result + 1] = line
        end
      end
    end
  end
  return result
end

---@param bufnr number
---@param lines string|string[]
local function append_to_buf(bufnr, lines)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  lines = normalize_to_lines(lines)
  if #lines == 0 then
    return
  end
  vim.bo[bufnr].modifiable = true
  local last_line = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, last_line, last_line, false, lines)
  vim.bo[bufnr].modifiable = false
  local winid = vim.fn.bufwinid(bufnr)
  if winid >= 0 then
    vim.api.nvim_win_set_cursor(winid, { vim.api.nvim_buf_line_count(bufnr), 0 })
  end
end

--- Filter out ibazel "sifting output" block (duplicate of build logs).
--- Accepts string or table of lines; returns filtered table of lines or nil.
local function filter_sifting_output(data, state)
  state = state or {}
  state.linebuf = state.linebuf or ""
  state.skipping = state.skipping or false
  local function process_line(line, out)
    if state.skipping then
      if line:find("iBazel %[") or line:find("using %d+ matching") then
        state.skipping = false
        table.insert(out, line)
      end
    else
      if line:find("sifting output") then
        state.skipping = true
      else
        table.insert(out, line)
      end
    end
  end

  local filtered = {}
  if type(data) == "table" then
    for _, line in ipairs(data) do
      if line and line ~= "" then
        process_line(line, filtered)
      end
    end
    if #filtered == 0 then return nil, state end
    return filtered, state
  end

  local input = type(data) == "string" and data or ""
  if input == "" then return nil, state end
  state.linebuf = state.linebuf .. input
  local last_newline = state.linebuf:match(".*\n()")
  if not last_newline then return nil, state end

  local complete = state.linebuf:sub(1, last_newline - 1)
  state.linebuf = state.linebuf:sub(last_newline)
  for _, line in ipairs(vim.split(complete, "\n", { plain = true })) do
    process_line(line, filtered)
  end
  if #filtered == 0 then return nil, state end
  return filtered, state
end

--- iBazel "no files to watch" message; only filtered when building targets in filter_no_watch_for_targets.
local NO_WATCH_PATTERN = "Didn't find any files to watch"

--- Build an append closure with optional clear_if and debounced ANSI refresh.
---@param bufnr number
---@param opts table|nil { clear_if, filter_sifting, filter_no_watch_for_targets = string[], current_targets = string[] }
---@return function(data) append function for stdout/stderr chunks
function M.make_append_with_ansi(bufnr, opts)
  opts = opts or {}
  local clear_if = opts.clear_if
  local filter_sifting = opts.filter_sifting
  local filter_no_watch = false
  if opts.filter_no_watch_for_targets and opts.current_targets and #opts.current_targets > 0 then
    local set = {}
    for _, t in ipairs(opts.filter_no_watch_for_targets) do set[t] = true end
    for _, t in ipairs(opts.current_targets) do
      if set[t] then filter_no_watch = true break end
    end
  end
  local sifting_state = {}
  local ansi_refresh_pending = false
  local function debounced_ansi_refresh()
    if ansi_refresh_pending then return end
    ansi_refresh_pending = true
    vim.defer_fn(function()
      ansi_refresh_pending = false
      if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(function() require("ansi.renderer").apply_ansi_highlighting(bufnr) end)
      end
    end, 80)
  end
  return function(data)
    if filter_sifting then
      local filtered, new_state = filter_sifting_output(data, sifting_state)
      sifting_state = new_state
      if not filtered or #filtered == 0 then return end
      data = filtered
    end
    if clear_if and clear_if(data) then
      vim.bo[bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
      vim.bo[bufnr].modifiable = false
    end
    local function should_append_line(line)
      if not line or line == "" then return false end
      if filter_no_watch and line:find(NO_WATCH_PATTERN, 1, true) then return false end
      return true
    end
    local function clean_line(line)
      if not line then return line end
      -- Remove carriage returns (used by NX for dynamic terminal updates)
      return line:gsub("\r", "")
    end
    if type(data) == "string" and data ~= "" then
      data = clean_line(data)
      local lines = vim.split(data, "\n", { plain = true })
      for _, line in ipairs(lines) do
        if should_append_line(line) then append_to_buf(bufnr, line) end
      end
      debounced_ansi_refresh()
    elseif type(data) == "table" then
      for _, line in ipairs(data) do
        line = clean_line(line)
        if should_append_line(line) then append_to_buf(bufnr, line) end
      end
      debounced_ansi_refresh()
    end
  end
end

return M
