local M = {}

M.defaults = {
  enabled = false,
  mode = "flow",
  capture = "insert",
  flow = {
    ewma_alpha = 0.25,
    perfect_ratio = 0.30,
    good_ratio = 0.80,
    pause_ms = 2000,
    min_interval_ms = 20,
    adaptive = true,
  },
  rhythm = {
    bpm = 120,
    subdivisions = 4,
    perfect_window_ms = 40,
    good_window_ms = 90,
    metronome = true,
    adaptive = true,
  },
  score = {
    perfect = 100,
    good = 50,
    combo_bonus = 5,
  },
  ui = {
    judgment = true,
    judgment_ttl_ms = 350,
    effects = true,
  },
  sound = {
    backend = "none",
    drums = true,
  },
  stats = {
    window = 200,
  },
  log = {
    enabled = false,
    flush_every = 50,
  },
  music = {
    file = nil,
    volume = 70,
    background_volume = 25,
    swell_ms = 500,
    gate = true,
    idle_ms = 1200,
    tail_beats = 4,
    fade_min_ms = 2500,
    fade_max_ms = 10000,
    fade_per_combo_ms = 50,
    autostart = false,
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
