local cfg = require("musicode.config")

local M = {}

local function system_play(judgment)
  if vim.fn.has("win32") ~= 1 then
    return
  end
  local freq = 440
  if judgment == "perfect" then
    freq = 880
  elseif judgment == "good" then
    freq = 660
  elseif judgment == "tick" then
    freq = 1320
  end
  vim.fn.jobstart(
    { "powershell", "-NoProfile", "-NonInteractive", "-Command", "[console]::beep(" .. freq .. ",60)" },
    { detach = true }
  )
end

function M.play(judgment)
  local backend = cfg.options.sound.backend
  if backend == "none" then
    return
  end
  if backend == "system" then
    if judgment == "perfect" or judgment == "good" or judgment == "miss" or judgment == "tick" then
      pcall(system_play, judgment)
    end
    return
  end
  if backend == "rpc" then
    if M.rpc_send then
      pcall(M.rpc_send, judgment)
    end
    return
  end
end

return M
