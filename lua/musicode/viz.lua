local engine = require("musicode.engine")
local daemon = require("musicode.daemon")
local cfg = require("musicode.config")

local M = {}
local win, buf, timer, pos_timer
local active = false
local frame = 0
local ns = vim.api.nvim_create_namespace("musicode_viz")

local BAR_COLS = 7
local BAR_MAX = 5
local VIZ_W = BAR_COLS * 2 + 1
local VIZ_H = BAR_MAX + 3

local COLORS = {
  "#ff5555", "#ffaa33", "#ffff33", "#55ff55", "#33ffff", "#5577ff", "#ff55ff",
}
local HL = {}
local HL_DIM = "MusicodeVizDim"
local prev_h = {}
local bands = nil
local track_secs = 0

for i = 1, BAR_COLS do
  prev_h[i] = 0
  HL[i] = "MusicodeVizBh" .. i
end

function M.setup_highlights()
  for i = 1, BAR_COLS do
    vim.api.nvim_set_hl(0, HL[i], { fg = COLORS[i], ctermfg = i + 8, bold = true, default = true })
  end
  vim.api.nvim_set_hl(0, HL_DIM, { fg = "#555555", ctermfg = "darkgrey", default = true })
end

function M.set_track(file)
  bands = nil
  track_secs = 0
  if not file then
    return
  end
  local sc = file .. ".beats.json"
  if vim.fn.filereadable(sc) == 0 then
    return
  end
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(sc), "\n"))
  end)
  if ok and type(data) == "table" and data.bands then
    bands = data.bands
    track_secs = data.track_secs or 0
  end
end

function M.clear_track()
  bands = nil
  track_secs = 0
end

local function bpm_val()
  local b = daemon.music_bpm()
  if not b or b <= 0 then
    b = engine.effective_bpm()
  end
  return math.max(1, b)
end

local function display()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local bpm = bpm_val()
  local sub = math.max(1, cfg.options.rhythm.subdivisions)
  local phase = (frame % sub) / sub
  local heights = {}
  if bands and #bands > 0 then
    local pos = daemon.music_pos_ms()
    local idx = math.floor(pos / 100) + 1
    if idx < 1 then
      idx = 1
    end
    if idx > #bands then
      idx = #bands
    end
    local row = bands[idx]
    for c = 0, BAR_COLS - 1 do
      heights[c + 1] = math.floor((row[c + 1] or 0) * BAR_MAX + 0.5)
    end
  else
    for c = 0, BAR_COLS - 1 do
      local p = (phase + c / BAR_COLS) % 1
      heights[c + 1] = math.floor(BAR_MAX * p + 0.5)
    end
  end

  local lines = {}
  for y = 0, BAR_MAX - 1 do
    local row = {}
    for c = 0, BAR_COLS - 1 do
      local h = heights[c + 1]
      local filled = y >= (BAR_MAX - h)
      row[#row + 1] = " "
      row[#row + 1] = filled and "█" or " "
    end
    row[#row + 1] = " "
    lines[#lines + 1] = table.concat(row)
  end
  lines[#lines + 1] = string.format(" %3d BPM ♪ ", bpm)
  local pbar = ""
  if track_secs > 0 then
    local pos = daemon.music_pos_ms() / 1000.0
    local ratio = math.max(0, math.min(1, pos / track_secs))
    local w = VIZ_W - 7
    local n = math.floor(w * ratio + 0.5)
    local t1 = string.format("%d:%02d", math.floor(pos / 60), math.floor(pos % 60))
    pbar = string.format(" %s%s] %s", string.rep("▓", n), string.rep("·", w - n), t1)
  end
  lines[#lines + 1] = pbar
  lines[#lines + 1] = string.format(
    " ♫%d|%d ",
    cfg.options.music.volume or 70,
    cfg.options.music.background_volume or 15
  )
  pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)

  for c = 0, BAR_COLS - 1 do
    local h = heights[c + 1]
    if h > 0 then
      local top = BAR_MAX - h
      for r = top, top + h - 1 do
        local cb = 1 + c * 4
        pcall(vim.api.nvim_buf_add_highlight, buf, ns, HL[c + 1], r, cb, cb + 3)
      end
    end
    if prev_h[c + 1] > h then
      for r = BAR_MAX - prev_h[c + 1], BAR_MAX - h - 1 do
        local cb = 1 + c * 4
        pcall(vim.api.nvim_buf_add_highlight, buf, ns, HL_DIM, r, cb, cb + 3)
      end
    end
    prev_h[c + 1] = h
  end
end

local function spawn()
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  local s, wid = pcall(vim.api.nvim_open_win, buf, false, {
    relative = "editor",
    width = VIZ_W,
    height = VIZ_H,
    row = vim.o.lines - VIZ_H - 1,
    col = vim.o.columns - VIZ_W - 2,
    style = "minimal",
    focusable = false,
    zindex = 10,
  })
  if s and wid then
    win = wid
    vim.api.nvim_win_set_option(win, "winblend", 30)
    pcall(vim.api.nvim_win_set_option, win, "winhighlight", "Normal:Normal,FloatBorder:Normal")
    M.setup_highlights()
    return win
  end
  return nil
end

local function close_win()
  if timer then
    pcall(vim.fn.timer_stop, timer)
    timer = nil
  end
  if pos_timer then
    pcall(vim.fn.timer_stop, pos_timer)
    pos_timer = nil
  end
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  win, buf = nil, nil
  frame = 0
  active = false
  for i = 1, BAR_COLS do
    prev_h[i] = 0
  end
end

local function tick()
  frame = frame + 1
  if win and vim.api.nvim_win_is_valid(win) then
    display()
  else
    close_win()
  end
end

local function start_timer()
  if timer then
    pcall(vim.fn.timer_stop, timer)
    timer = nil
  end
  local bpm = bpm_val()
  local period = (60000 / bpm) / math.max(1, cfg.options.rhythm.subdivisions)
  if period < 20 then
    period = 20
  end
  timer = vim.fn.timer_start(math.floor(period), tick, { ["repeat"] = -1 })
end

local function start_pos_poll()
  if pos_timer then
    pcall(vim.fn.timer_stop, pos_timer)
    pos_timer = nil
  end
  if not daemon.is_running() then
    return
  end
  pos_timer = vim.fn.timer_start(250, function()
    daemon.query_pos()
  end, { ["repeat"] = -1 })
end

function M.start()
  if active then
    return
  end
  spawn()
  if not win then
    return
  end
  active = true
  start_timer()
  start_pos_poll()
  display()
  vim.notify("musicode viz on", vim.log.levels.INFO)
end

function M.stop()
  close_win()
end

function M.toggle()
  if active then
    M.stop()
  else
    M.start()
  end
end

function M.is_active()
  return active
end

return M
