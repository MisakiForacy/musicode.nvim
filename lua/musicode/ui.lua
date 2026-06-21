local cfg = require("musicode.config")

local M = {}

local ns = vim.api.nvim_create_namespace("musicode_ui")
local last = { buf = nil, id = nil }

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
end

local function clear_last()
  if last.buf and last.id and vim.api.nvim_buf_is_valid(last.buf) then
    pcall(vim.api.nvim_buf_del_extmark, last.buf, ns, last.id)
  end
  last.buf, last.id = nil, nil
end

function M.show(result)
  if not cfg.options.ui.judgment then
    return
  end
  local label = labels[result.judgment]
  if not label then
    return
  end
  local text = label
  if result.combo and result.combo > 1 and result.judgment ~= "miss" then
    text = label .. " x" .. result.combo
  end
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  clear_last()
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, {
    virt_text = { { "  " .. text, hl[result.judgment] or "Comment" } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
  if ok then
    last.buf, last.id = buf, id
    local captured = id
    vim.defer_fn(function()
      if last.id == captured then
        clear_last()
      end
    end, cfg.options.ui.judgment_ttl_ms)
  end
end

function M.clear()
  clear_last()
end

return M
