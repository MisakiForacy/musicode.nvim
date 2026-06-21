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
