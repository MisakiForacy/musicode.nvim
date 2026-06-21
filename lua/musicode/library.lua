local sound = require("musicode.sound")

local M = {}

local list = {}
local idx = 0
local order = "sequence"

math.randomseed(os.time())

local exts = {
  mp3 = true,
  ogg = true,
  wav = true,
  flac = true,
  m4a = true,
}

function M.scan(dir)
  list = {}
  idx = 0
  if not dir or dir == "" then
    return list
  end
  dir = vim.fn.expand(dir)
  local entries = vim.fn.glob(dir .. "/*", false, true)
  for _, p in ipairs(entries) do
    local ext = p:match("%.([%w]+)$")
    if ext and exts[ext:lower()] then
      list[#list + 1] = p
    end
  end
  table.sort(list)
  return list
end

function M.count()
  return #list
end

function M.list()
  return list
end

function M.analyze_all(force)
  if not sound.rpc_send then
    return 0
  end
  local n = 0
  for _, p in ipairs(list) do
    if force or vim.fn.filereadable(p .. ".beats.json") == 0 then
      sound.rpc_send("analyze " .. p)
      n = n + 1
    end
  end
  return n
end

function M.current()
  if idx >= 1 and idx <= #list then
    return list[idx]
  end
  return nil
end

function M.next()
  if #list == 0 then
    return nil
  end
  idx = idx % #list + 1
  return list[idx]
end

function M.prev()
  if #list == 0 then
    return nil
  end
  idx = (idx - 2) % #list + 1
  return list[idx]
end

function M.set_to(path)
  for i, p in ipairs(list) do
    if p == path then
      idx = i
      return
    end
  end
end

function M.set_order(o)
  if o == "sequence" or o == "shuffle" or o == "repeat_one" then
    order = o
  end
  return order
end

function M.get_order()
  return order
end

function M.advance()
  if #list == 0 then
    return nil
  end
  if order == "repeat_one" then
    if idx < 1 then
      idx = 1
    end
  elseif order == "shuffle" then
    if #list == 1 then
      idx = 1
    else
      local r = idx
      while r == idx do
        r = math.random(#list)
      end
      idx = r
    end
  else
    idx = idx % #list + 1
  end
  return list[idx]
end

return M
