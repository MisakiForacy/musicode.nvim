local M = {}

local augroup
local onkey_ns

function M.start(opts, on_event)
  M.stop()
  if opts.capture == "all" then
    onkey_ns = vim.on_key(function()
      local m = vim.api.nvim_get_mode().mode
      if m:sub(1, 1) == "i" then
        on_event()
      end
    end)
  else
    augroup = vim.api.nvim_create_augroup("MusicodeCapture", { clear = true })
    vim.api.nvim_create_autocmd("InsertCharPre", {
      group = augroup,
      callback = function()
        on_event()
      end,
    })
  end
end

function M.stop()
  if onkey_ns then
    pcall(vim.on_key, nil, onkey_ns)
    onkey_ns = nil
  end
  if augroup then
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    augroup = nil
  end
end

return M
