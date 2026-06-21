local M = {}

local buf = {}
local path = nil
local cap = 50
local enabled = false

local function default_path()
  local dir = vim.fn.stdpath("data") .. "/musicode"
  vim.fn.mkdir(dir, "p")
  return dir .. "/rhythm.jsonl"
end

function M.configure(opts)
  opts = opts or {}
  enabled = opts.enabled or false
  cap = opts.flush_every or 50
  path = opts.path
  if enabled and not path then
    path = default_path()
  end
end

function M.is_enabled()
  return enabled
end

function M.path()
  return path
end

function M.set_enabled(v)
  enabled = v and true or false
  if enabled and not path then
    path = default_path()
  end
  return enabled
end

function M.record(entry)
  if not enabled then
    return
  end
  buf[#buf + 1] = vim.json.encode(entry)
  if #buf >= cap then
    M.flush()
  end
end

function M.flush()
  if #buf == 0 or not path then
    return
  end
  local lines = buf
  buf = {}
  local ok, fd = pcall(io.open, path, "a")
  if ok and fd then
    fd:write(table.concat(lines, "\n") .. "\n")
    fd:close()
  end
end

return M
