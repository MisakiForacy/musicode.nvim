local M = {}

M.defaults = {
  enabled = false,
  mode = "flow",
  capture = "insert",
  flow = {
    ewma_alpha = 0.25,
    perfect_ratio = 0.30,
    good_ratio = 0.80,
    pause_ms = 1500,
    min_interval_ms = 20,
  },
  rhythm = {
    bpm = 120,
    subdivisions = 4,
    perfect_window_ms = 40,
    good_window_ms = 90,
    metronome = true,
  },
  score = {
    perfect = 100,
    good = 50,
    combo_bonus = 5,
  },
  ui = {
    judgment = true,
    judgment_ttl_ms = 350,
  },
  sound = {
    backend = "none",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
