local cfg = require("musicode.config")

local M = {}

local ns = vim.api.nvim_create_namespace("musicode_ui")
local last = { buf = nil, id = nil }
local anim_gen = 0

local labels = {
  perfect = "PERFECT",
  good = "GOOD",
  miss = "MISS",
  off = "~",
}

local hl = {
  perfect = "MusicodePerfect",
  good = "MusicodeGood",
  miss = "MusicodeMiss",
  off = "MusicodeOff",
}

function M.setup_highlights()
  local function def(name, link)
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
  def("MusicodePerfect", "DiagnosticOk")
  def("MusicodeGood", "DiagnosticInfo")
  def("MusicodeMiss", "DiagnosticError")
  def("MusicodeOff", "Comment")
  def("MusicodeCombo", "WarningMsg")
  vim.api.nvim_set_hl(0, "MusicodeFlash", { fg = "#ffffff", bold = true, default = true })
end

local function clear_last()
  if last.buf and last.id and vim.api.nvim_buf_is_valid(last.buf) then
    pcall(vim.api.nvim_buf_del_extmark, last.buf, ns, last.id)
  end
  last.buf, last.id = nil, nil
end

local function render(buf, row, text, hlname, id)
  local opts = {
    virt_text = { { text, hlname } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  }
  if id then
    opts.id = id
  end
  local ok, newid = pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, opts)
  if ok then
    return newid
  end
  return id
end

local function build(label, combo, judgment, frame)
  local cs = ""
  if combo and combo > 1 and judgment ~= "miss" then
    cs = " x" .. combo
  end
  local lvl = math.min(5, math.floor((combo or 0) / 6))
  local lead, tail
  if frame == 1 then
    lead = "✦ "
    tail = " ✦"
  elseif frame == 2 then
    lead = "✧ ✦ "
    tail = " ✦ ✧" .. string.rep(" ·", lvl)
  else
    lead = "· ˖ ✧ ✦ "
    tail = " ✦ ✧ ˖" .. string.rep(" ·", 1 + lvl)
  end
  return "  " .. lead .. label .. cs .. tail
end

function M.show(result)
  if not cfg.options.ui.judgment then
    return
  end
  local judgment = result.judgment
  local label = labels[judgment]
  if not label then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  anim_gen = anim_gen + 1
  local g = anim_gen
  clear_last()

  if not cfg.options.ui.effects or judgment == "off" then
    local text = "  " .. label
    if result.combo and result.combo > 1 and judgment ~= "miss" then
      text = text .. " x" .. result.combo
    end
    last.buf = buf
    last.id = render(buf, row, text, hl[judgment] or "MusicodeOff")
    vim.defer_fn(function()
      if g == anim_gen then
        clear_last()
      end
    end, cfg.options.ui.judgment_ttl_ms)
    return
  end

  local combo = result.combo or 0
  local base = hl[judgment] or "MusicodeOff"

  last.buf = buf
  last.id = render(buf, row, build(label, combo, judgment, 1), "MusicodeFlash")

  vim.defer_fn(function()
    if g ~= anim_gen then
      return
    end
    last.id = render(buf, row, build(label, combo, judgment, 2), base, last.id)
  end, 70)

  vim.defer_fn(function()
    if g ~= anim_gen then
      return
    end
    last.id = render(buf, row, build(label, combo, judgment, 3), "MusicodeOff", last.id)
  end, 150)

  local ttl = math.max(cfg.options.ui.judgment_ttl_ms or 350, 420)
  vim.defer_fn(function()
    if g == anim_gen then
      clear_last()
    end
  end, ttl)
end

function M.clear()
  clear_last()
end

return M
