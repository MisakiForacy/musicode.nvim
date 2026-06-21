local cfg = require("musicode.config")
local engine = require("musicode.engine")
local capture = require("musicode.capture")
local ui = require("musicode.ui")
local sound = require("musicode.sound")
local daemon = require("musicode.daemon")
local stats = require("musicode.stats")
local log = require("musicode.log")

local M = {}

local metronome_timer
local music_idle_timer
local music_ramp_timer
local music_loaded = false
local music_vol_cur = 0

local function stop_metronome()
  if metronome_timer then
    pcall(vim.fn.timer_stop, metronome_timer)
    metronome_timer = nil
  end
end

local function start_metronome()
  stop_metronome()
  local o = cfg.options
  if o.mode ~= "rhythm" or not o.rhythm.metronome then
    return
  end
  if o.sound.backend == "none" then
    return
  end
  local period = math.floor((60000 / engine.effective_bpm()) / o.rhythm.subdivisions)
  if period < 1 then
    period = 1
  end
  metronome_timer = vim.fn.timer_start(period, function()
    sound.play("tick")
  end, { ["repeat"] = -1 })
end

local function update_beat()
  if cfg.options.sound.backend == "rpc" and sound.rpc_send then
    sound.rpc_send("beat " .. engine.effective_bpm() .. " " .. cfg.options.rhythm.subdivisions)
  end
end

local function music_tail_ms()
  local bpm = daemon.music_bpm()
  if not bpm or bpm <= 0 then
    bpm = engine.effective_bpm()
  end
  if not bpm or bpm <= 0 then
    return cfg.options.music.idle_ms or 1200
  end
  return math.floor((cfg.options.music.tail_beats or 4) * 60000 / bpm)
end

local function stop_ramp()
  if music_ramp_timer then
    pcall(vim.fn.timer_stop, music_ramp_timer)
    music_ramp_timer = nil
  end
end

local function ramp_volume(target, duration_ms)
  stop_ramp()
  if not sound.rpc_send then
    music_vol_cur = target
    return
  end
  local start = music_vol_cur
  if duration_ms <= 0 or start == target then
    music_vol_cur = target
    sound.rpc_send("musicvol " .. target)
    return
  end
  local steps = math.max(1, math.floor(duration_ms / 50))
  local interval = math.max(20, math.floor(duration_ms / steps))
  local i = 0
  music_ramp_timer = vim.fn.timer_start(interval, function()
    i = i + 1
    local v = math.floor(start + (target - start) * (i / steps))
    music_vol_cur = v
    if sound.rpc_send then
      sound.rpc_send("musicvol " .. v)
    end
    if i >= steps then
      music_vol_cur = target
      if sound.rpc_send then
        sound.rpc_send("musicvol " .. target)
      end
      stop_ramp()
    end
  end, { ["repeat"] = -1 })
end

local function swell_up()
  local m = cfg.options.music
  ramp_volume(m.volume or 70, m.swell_ms or 500)
end

local function fade_down()
  local m = cfg.options.music
  local combo = engine.state().combo or 0
  local fmin = m.fade_min_ms or 2500
  local fmax = m.fade_max_ms or 10000
  local dur = fmin + combo * (m.fade_per_combo_ms or 50)
  if dur < fmin then
    dur = fmin
  end
  if dur > fmax then
    dur = fmax
  end
  ramp_volume(m.background_volume or 25, dur)
end

local function on_event()
  local now = vim.loop.hrtime() / 1e6
  local result = engine.feed(now)
  ui.show(result)
  if cfg.options.sound.backend == "rpc" and cfg.options.sound.drums and sound.rpc_send then
    sound.rpc_send("hit")
  else
    sound.play(result.judgment)
  end
  log.record({
    t = now,
    j = result.judgment,
    combo = result.combo,
    bpm = result.bpm,
    mode = engine.get_mode(),
    ft = vim.bo.filetype,
  })
  if music_loaded then
    if engine.get_mode() == "flow" and cfg.options.music.gate then
      if music_vol_cur < (cfg.options.music.volume or 70) then
        swell_up()
      end
      if music_idle_timer then
        pcall(vim.fn.timer_stop, music_idle_timer)
      end
      music_idle_timer = vim.fn.timer_start(music_tail_ms(), function()
        fade_down()
        music_idle_timer = nil
      end)
    end
  end
end

function M.enable()
  cfg.options.enabled = true
  ui.setup_highlights()
  engine.set_mode(cfg.options.mode)
  capture.start(cfg.options, on_event)
  if cfg.options.sound.backend == "rpc" then
    daemon.start(cfg.options.sound)
  end
  update_beat()
  if cfg.options.music.autostart and cfg.options.music.file then
    M.start_music()
  end
  start_metronome()
  vim.notify("musicode enabled (" .. cfg.options.mode .. ")", vim.log.levels.INFO)
end

function M.disable()
  cfg.options.enabled = false
  capture.stop()
  stop_metronome()
  M.stop_music()
  daemon.stop()
  log.flush()
  ui.clear()
  vim.notify("musicode disabled", vim.log.levels.INFO)
end

function M.toggle()
  if cfg.options.enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.set_mode(m)
  if m ~= "flow" and m ~= "rhythm" then
    vim.notify("musicode: unknown mode '" .. tostring(m) .. "'", vim.log.levels.WARN)
    return
  end
  cfg.options.mode = m
  engine.set_mode(m)
  update_beat()
  if music_loaded then
    if music_idle_timer then
      pcall(vim.fn.timer_stop, music_idle_timer)
      music_idle_timer = nil
    end
    if m == "rhythm" then
      ramp_volume(cfg.options.music.volume or 70, 300)
    end
  end
  if cfg.options.enabled then
    start_metronome()
    vim.notify("musicode mode: " .. m, vim.log.levels.INFO)
  end
end

function M.stats()
  local s = engine.state()
  local lines = {
    "musicode stats",
    "mode      : " .. s.mode,
    "score     : " .. s.score,
    "max combo : " .. s.max_combo,
    "perfect   : " .. s.perfect,
    "good      : " .. s.good,
    "miss      : " .. s.miss,
    "bpm       : " .. s.bpm,
    "samples   : " .. stats.count(),
    "interval  : " .. string.format("%.0f ms (median %.0f)", stats.mean(), stats.median()),
    "adapt bpm : " .. engine.effective_bpm(),
    "logging   : " .. (log.is_enabled() and ("on -> " .. tostring(log.path())) or "off"),
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.toggle_log(value)
  local v
  if value == nil then
    v = not log.is_enabled()
  else
    v = value
  end
  log.set_enabled(v)
  if v then
    vim.notify("musicode logging on -> " .. tostring(log.path()), vim.log.levels.INFO)
  else
    log.flush()
    vim.notify("musicode logging off", vim.log.levels.INFO)
  end
  return v
end

function M.start_music(file)
  local s = cfg.options.sound
  local m = cfg.options.music
  if s.backend ~= "rpc" then
    vim.notify("musicode: background music requires sound.backend = 'rpc'", vim.log.levels.WARN)
    return false
  end
  if file then
    m.file = file
  end
  if not m.file or m.file == "" then
    vim.notify("musicode: set music.file to your audio path first", vim.log.levels.WARN)
    return false
  end
  if not daemon.start(s) then
    return false
  end
  if not sound.rpc_send then
    return false
  end
  local full = m.volume or 70
  local bg = m.background_volume or 25
  local start_vol = full
  if engine.get_mode() == "flow" and m.gate then
    start_vol = bg
  end
  sound.rpc_send("musicvol " .. start_vol)
  sound.rpc_send("music " .. m.file)
  music_loaded = true
  music_vol_cur = start_vol
  vim.notify("musicode music: " .. m.file, vim.log.levels.INFO)
  return true
end

function M.stop_music()
  if music_idle_timer then
    pcall(vim.fn.timer_stop, music_idle_timer)
    music_idle_timer = nil
  end
  stop_ramp()
  if sound.rpc_send then
    sound.rpc_send("musicstop")
  end
  music_loaded = false
  music_vol_cur = 0
end

function M.toggle_music()
  if music_loaded then
    M.stop_music()
  else
    M.start_music()
  end
end

function M.statusline()
  if not cfg.options.enabled then
    return ""
  end
  local s = engine.state()
  return string.format("MC[%s] x%d %dBPM", s.mode, s.combo, s.bpm)
end

function M.setup(opts)
  cfg.setup(opts)
  stats.configure(cfg.options.stats.window)
  log.configure(cfg.options.log)
  ui.setup_highlights()
  local grp = vim.api.nvim_create_augroup("MusicodeCore", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = grp,
    callback = function()
      ui.setup_highlights()
    end,
  })
  vim.api.nvim_create_autocmd({ "InsertLeave", "VimLeavePre" }, {
    group = grp,
    callback = function()
      log.flush()
    end,
  })
  if cfg.options.enabled then
    M.enable()
  end
  return M
end

return M
