local sound = require("musicode.sound")

local M = {}

local job
local music_bpm

local function plugin_root()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":h:h:h")
end

local function default_bin()
  local exe = plugin_root() .. "/daemon/target/release/musicode-daemon"
  if vim.fn.has("win32") == 1 then
    exe = exe .. ".exe"
  end
  return exe
end

function M.start(cfg_sound)
  if job then
    return true
  end
  local cmd
  if cfg_sound.daemon_cmd then
    cmd = cfg_sound.daemon_cmd
  else
    local bin = default_bin()
    if vim.fn.filereadable(bin) == 0 then
      vim.notify(
        "musicode: audio daemon not built. Run `cargo build --release` in " .. plugin_root() .. "/daemon",
        vim.log.levels.WARN
      )
      return false
    end
    cmd = { bin }
  end
  local id = vim.fn.jobstart(cmd, {
    on_exit = function()
      job = nil
      sound.rpc_send = nil
    end,
    on_stderr = function(_, data)
      for _, l in ipairs(data or {}) do
        local b = l:match("~([%d%.]+) bpm")
        if b then
          music_bpm = tonumber(b)
        end
      end
    end,
  })
  if id <= 0 then
    job = nil
    vim.notify("musicode: failed to start audio daemon", vim.log.levels.ERROR)
    return false
  end
  job = id
  sound.rpc_send = function(judgment)
    if job then
      pcall(vim.fn.chansend, job, judgment .. "\n")
    end
  end
  return true
end

function M.stop()
  if not job then
    return
  end
  pcall(vim.fn.chansend, job, "quit\n")
  pcall(vim.fn.jobstop, job)
  job = nil
  sound.rpc_send = nil
end

function M.is_running()
  return job ~= nil
end

function M.music_bpm()
  return music_bpm
end

return M
