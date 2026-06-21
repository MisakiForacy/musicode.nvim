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
