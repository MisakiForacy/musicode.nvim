local cfg = require("musicode.config")
local stats = require("musicode.stats")

local M = {}

local state = {
  mode = "flow",
  last_ts = nil,
  stats_last = nil,
  ewma = nil,
  t0 = nil,
  combo = 0,
  max_combo = 0,
  score = 0,
  bpm = 0,
  total = 0,
  perfect = 0,
  good = 0,
  miss = 0,
}

function M.reset()
  state.last_ts = nil
  state.stats_last = nil
  state.ewma = nil
  state.t0 = nil
  state.combo = 0
  state.max_combo = 0
  state.score = 0
  state.bpm = 0
  state.total = 0
  state.perfect = 0
  state.good = 0
  state.miss = 0
end

function M.set_mode(m)
  if m == "flow" or m == "rhythm" then
    state.mode = m
    state.last_ts = nil
    state.t0 = nil
    state.combo = 0
  end
end

function M.get_mode()
  return state.mode
end

function M.state()
  return state
end

function M.effective_bpm()
  local o = cfg.options.rhythm
  if not o.adaptive then
    return o.bpm
  end
  if stats.count() < 30 then
    return o.bpm
  end
  local med = stats.median()
  if med <= 0 then
    return o.bpm
  end
  local bpm = math.floor(60000 / (med * o.subdivisions) + 0.5)
  return math.max(40, math.min(300, bpm))
end

local function flow_windows(o)
  if not o.adaptive or stats.count() < 20 then
    return o.perfect_ratio, o.good_ratio
  end
  local m = stats.mean()
  if m <= 0 then
    return o.perfect_ratio, o.good_ratio
  end
  local cv = stats.std() / m
  local pr = math.min(o.perfect_ratio * (1 + cv), 0.6)
  local gr = math.min(o.good_ratio * (1 + cv), 1.5)
  return pr, gr
end

local function bump(judgment)
  local o = cfg.options
  if judgment == "perfect" then
    state.combo = state.combo + 1
    state.perfect = state.perfect + 1
    state.score = state.score + o.score.perfect + state.combo * o.score.combo_bonus
  elseif judgment == "good" then
    state.combo = state.combo + 1
    state.good = state.good + 1
    state.score = state.score + o.score.good + state.combo * o.score.combo_bonus
  elseif judgment == "miss" then
    state.miss = state.miss + 1
    state.combo = 0
  end
  if state.combo > state.max_combo then
    state.max_combo = state.combo
  end
end

local function flow_feed(now)
  local o = cfg.options.flow
  if not state.last_ts then
    state.last_ts = now
    return { judgment = "start", combo = state.combo, score = state.score, bpm = state.bpm }
  end
  local dt = now - state.last_ts
  state.last_ts = now
  if dt > o.pause_ms then
    state.combo = 0
    return { judgment = "pause", combo = 0, score = state.score, bpm = state.bpm }
  end
  if dt < o.min_interval_ms then
    dt = o.min_interval_ms
  end
  local judgment
  if not state.ewma then
    state.ewma = dt
    judgment = "good"
    bump("good")
  else
    local pr, gr = flow_windows(o)
    local ratio = math.abs(dt - state.ewma) / state.ewma
    if ratio <= pr then
      judgment = "perfect"
      bump("perfect")
    elseif ratio <= gr then
      judgment = "good"
      bump("good")
    else
      judgment = "off"
    end
    state.ewma = o.ewma_alpha * dt + (1 - o.ewma_alpha) * state.ewma
  end
  state.bpm = math.floor(60000 / state.ewma + 0.5)
  return { judgment = judgment, combo = state.combo, score = state.score, bpm = state.bpm }
end

local function rhythm_feed(now)
  local o = cfg.options.rhythm
  local bpm = M.effective_bpm()
  state.bpm = bpm
  if not state.t0 then
    state.t0 = now
    state.last_ts = now
    return { judgment = "start", combo = state.combo, score = state.score, bpm = state.bpm }
  end
  state.last_ts = now
  local period = (60000 / bpm) / o.subdivisions
  local phase = (now - state.t0) % period
  local dist = math.min(phase, period - phase)
  local judgment
  if dist <= o.perfect_window_ms then
    judgment = "perfect"
    bump("perfect")
  elseif dist <= o.good_window_ms then
    judgment = "good"
    bump("good")
  else
    judgment = "miss"
    bump("miss")
  end
  return { judgment = judgment, combo = state.combo, score = state.score, bpm = state.bpm }
end

function M.feed(now)
  state.total = state.total + 1
  if state.stats_last then
    local dt = now - state.stats_last
    if dt > 0 and dt <= cfg.options.flow.pause_ms then
      stats.record(dt)
    end
  end
  state.stats_last = now
  if state.mode == "rhythm" then
    return rhythm_feed(now)
  end
  return flow_feed(now)
end

return M
