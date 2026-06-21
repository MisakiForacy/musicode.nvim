local M = {}

local samples = {}
local idx = 0
local n = 0
local cap = 200

function M.configure(window)
  cap = window or 200
  M.reset()
end

function M.reset()
  samples = {}
  idx = 0
  n = 0
end

function M.record(dt)
  idx = idx % cap + 1
  samples[idx] = dt
  if n < cap then
    n = n + 1
  end
end

function M.count()
  return n
end

function M.mean()
  if n == 0 then
    return 0
  end
  local s = 0
  for i = 1, n do
    s = s + samples[i]
  end
  return s / n
end

function M.std()
  if n < 2 then
    return 0
  end
  local m = M.mean()
  local s = 0
  for i = 1, n do
    local d = samples[i] - m
    s = s + d * d
  end
  return math.sqrt(s / (n - 1))
end

function M.median()
  if n == 0 then
    return 0
  end
  local t = {}
  for i = 1, n do
    t[i] = samples[i]
  end
  table.sort(t)
  local mid = math.floor(n / 2)
  if n % 2 == 1 then
    return t[mid + 1]
  end
  return (t[mid] + t[mid + 1]) / 2
end

return M
