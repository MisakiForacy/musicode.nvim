local M = {}

local profile = nil

local function data_dir()
  local dir = vim.fn.stdpath("data") .. "/musicode"
  vim.fn.mkdir(dir, "p")
  return dir
end

local function profile_path()
  return data_dir() .. "/profile.json"
end

local function log_path()
  return data_dir() .. "/rhythm.jsonl"
end

local function clamp(x, lo, hi)
  if x < lo then
    return lo
  end
  if x > hi then
    return hi
  end
  return x
end

local function median(t)
  local n = #t
  if n == 0 then
    return 0
  end
  table.sort(t)
  local m = math.floor(n / 2)
  if n % 2 == 1 then
    return t[m + 1]
  end
  return (t[m] + t[m + 1]) / 2
end

local function mean(t)
  local n = #t
  if n == 0 then
    return 0
  end
  local s = 0
  for i = 1, n do
    s = s + t[i]
  end
  return s / n
end

local function stddev(t, mu)
  local n = #t
  if n < 2 then
    return 0
  end
  local s = 0
  for i = 1, n do
    local d = t[i] - mu
    s = s + d * d
  end
  return math.sqrt(s / (n - 1))
end

local function summarize(b)
  local mu = mean(b.dts)
  local sd = stddev(b.dts, mu)
  local med = median(b.dts)
  local acc = b.total > 0 and (b.perfect + 0.5 * b.good) / b.total or 0
  return { median = med, mean = mu, std = sd, n = #b.dts, acc = acc }
end

local function skill_of(g)
  local cv = (g.mean and g.mean > 0) and (g.std / g.mean) or 1
  local s = 0.5 * (1 - math.min(cv, 1)) + 0.5 * (g.acc or 0)
  return clamp(s, 0, 1)
end

function M.load()
  local p = profile_path()
  if vim.fn.filereadable(p) == 1 then
    local ok, data = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(p), "\n"))
    end)
    if ok and type(data) == "table" then
      profile = data
    end
  end
  return profile
end

function M.get()
  return profile
end

function M.skill()
  return profile and profile.skill or nil
end

function M.difficulty()
  local s = M.skill()
  if not s then
    return 1.0
  end
  return clamp(1.3 - 0.6 * s, 0.6, 1.4)
end

function M.predict(ft)
  if not profile then
    return nil
  end
  local entry = (profile.per_ft and profile.per_ft[ft]) or profile.global
  return entry
end

function M.train_from_log(path)
  path = path or log_path()
  if vim.fn.filereadable(path) == 0 then
    return nil, "no log at " .. path
  end
  local lines = vim.fn.readfile(path)
  local by_ft = {}
  local all = { dts = {}, perfect = 0, good = 0, miss = 0, total = 0 }
  local prev_t = nil
  for _, ln in ipairs(lines) do
    local ok, e = pcall(vim.json.decode, ln)
    if ok and type(e) == "table" and e.t then
      local ft = (e.ft and e.ft ~= "") and e.ft or "_"
      local bucket = by_ft[ft]
      if not bucket then
        bucket = { dts = {}, perfect = 0, good = 0, miss = 0, total = 0 }
        by_ft[ft] = bucket
      end
      if prev_t and e.t > prev_t then
        local dt = e.t - prev_t
        if dt > 20 and dt < 1500 then
          bucket.dts[#bucket.dts + 1] = dt
          all.dts[#all.dts + 1] = dt
        end
      end
      if e.j == "perfect" then
        bucket.perfect = bucket.perfect + 1
        all.perfect = all.perfect + 1
      elseif e.j == "good" then
        bucket.good = bucket.good + 1
        all.good = all.good + 1
      elseif e.j == "miss" then
        bucket.miss = bucket.miss + 1
        all.miss = all.miss + 1
      end
      bucket.total = bucket.total + 1
      all.total = all.total + 1
      prev_t = e.t
    end
  end
  local per_ft = {}
  for ft, b in pairs(by_ft) do
    per_ft[ft] = summarize(b)
  end
  local global = summarize(all)
  profile = {
    per_ft = per_ft,
    global = global,
    skill = skill_of(global),
    generated = os.time(),
  }
  vim.fn.writefile({ vim.json.encode(profile) }, profile_path())
  return profile
end

return M
