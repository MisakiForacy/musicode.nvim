if vim.g.loaded_musicode then
  return
end
vim.g.loaded_musicode = true

vim.api.nvim_create_user_command("MusicodeToggle", function()
  require("musicode").toggle()
end, {})

vim.api.nvim_create_user_command("MusicodeEnable", function()
  require("musicode").enable()
end, {})

vim.api.nvim_create_user_command("MusicodeDisable", function()
  require("musicode").disable()
end, {})

vim.api.nvim_create_user_command("MusicodeMode", function(a)
  require("musicode").set_mode(a.args)
end, {
  nargs = 1,
  complete = function()
    return { "flow", "rhythm" }
  end,
})

vim.api.nvim_create_user_command("MusicodeStats", function()
  require("musicode").stats()
end, {})

vim.api.nvim_create_user_command("MusicodeReset", function()
  require("musicode.engine").reset()
end, {})

vim.api.nvim_create_user_command("MusicodeLog", function(a)
  if a.args == "on" then
    require("musicode").toggle_log(true)
  elseif a.args == "off" then
    require("musicode").toggle_log(false)
  else
    require("musicode").toggle_log()
  end
end, {
  nargs = "?",
  complete = function()
    return { "on", "off" }
  end,
})

vim.api.nvim_create_user_command("MusicodeMusic", function(a)
  local mc = require("musicode")
  if a.args == "" then
    mc.toggle_music()
  elseif a.args == "on" then
    mc.start_music()
  elseif a.args == "off" then
    mc.stop_music()
  else
    mc.start_music(a.args)
  end
end, { nargs = "?", complete = "file" })

vim.api.nvim_create_user_command("MusicodeTrain", function()
  require("musicode").train()
end, {})

vim.api.nvim_create_user_command("MusicodeLibrary", function()
  require("musicode").library_scan()
end, {})

vim.api.nvim_create_user_command("MusicodeNext", function()
  require("musicode").music_next()
end, {})

vim.api.nvim_create_user_command("MusicodePrev", function()
  require("musicode").music_prev()
end, {})

vim.api.nvim_create_user_command("MusicodeOrder", function(a)
  require("musicode").set_order(a.args ~= "" and a.args or nil)
end, {
  nargs = "?",
  complete = function()
    return { "sequence", "shuffle", "repeat_one" }
  end,
})

vim.api.nvim_create_user_command("MusicodePick", function()
  require("musicode").music_pick()
end, {})

vim.api.nvim_create_user_command("MusicodeVolume", function(a)
  local args = vim.split(vim.trim(a.args), "%s+", { trimempty = true })
  local mc = require("musicode")
  if #args == 0 then
    mc.volume_info()
    return
  end
  if args[1] then
    mc.set_fg(tonumber(args[1]))
  end
  if args[2] then
    mc.set_bg(tonumber(args[2]))
  end
end, { nargs = "*" })
