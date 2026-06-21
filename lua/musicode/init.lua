local cfg = require("musicode.config")
local engine = require("musicode.engine")
local capture = require("musicode.capture")
local ui = require("musicode.ui")
local sound = require("musicode.sound")

local M = {}

local metronome_timer

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
  local period = math.floor((60000 / o.rhythm.bpm) / o.rhythm.subdivisions)
  if period < 1 then
    period = 1
  end
  metronome_timer = vim.fn.timer_start(period, function()
    sound.play("tick")
  end, { ["repeat"] = -1 })
end

local function on_event()
  local now = vim.loop.hrtime() / 1e6
  local result = engine.feed(now)
  ui.show(result)
  sound.play(result.judgment)
end

function M.enable()
  cfg.options.enabled = true
  ui.setup_highlights()
  engine.set_mode(cfg.options.mode)
  capture.start(cfg.options, on_event)
  start_metronome()
  vim.notify("musicode enabled (" .. cfg.options.mode .. ")", vim.log.levels.INFO)
end

function M.disable()
  cfg.options.enabled = false
  capture.stop()
  stop_metronome()
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
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
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
  ui.setup_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      ui.setup_highlights()
    end,
  })
  if cfg.options.enabled then
    M.enable()
  end
  return M
end

return M
