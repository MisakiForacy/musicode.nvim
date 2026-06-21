local cfg = require("musicode.config")

local M = {}

local state = {
  mode = "flow",
  last_ts = nil,
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
    local ratio = math.abs(dt - state.ewma) / state.ewma
    if ratio <= o.perfect_ratio then
      judgment = "perfect"
      bump("perfect")
    elseif ratio <= o.good_ratio then
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
  state.bpm = o.bpm
  if not state.t0 then
    state.t0 = now
    state.last_ts = now
    return { judgment = "start", combo = state.combo, score = state.score, bpm = state.bpm }
  end
  state.last_ts = now
  local period = (60000 / o.bpm) / o.subdivisions
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
  if state.mode == "rhythm" then
    return rhythm_feed(now)
  end
  return flow_feed(now)
end

return M
