# musicode.nvim

Type code (and prose) with the feel of a rhythm game. musicode turns your keystrokes
into real-time combos and judgments, so writing has momentum — built for people with a
continuous typing flow such as competitive programmers and web novelists.

让写代码 / 写文像玩音游一样有节奏感：实时连击、判定特效，跟随你自己的击键节奏，
长时间停顿不会被判 Miss。

> Status: MVP (pure Lua, zero dependencies). Low-latency audio via a companion Rust
> daemon is on the roadmap (`sound.backend = "rpc"`).

## Features

- **Two switchable modes**
  - `flow` — follows *your own* cadence (EWMA of keystroke intervals). Long thinking
    pauses only break the combo, they are never penalized as a miss.
  - `rhythm` — judges keystrokes against a fixed BPM grid (PERFECT / GOOD / MISS),
    like a real rhythm game.
- Combo counter, score, and live BPM estimate.
- In-buffer judgment popups via extmarks (no extra UI window).
- Statusline component.
- Pluggable sound backend (`none` / `system` / `rpc`).

## Requirements

- Neovim >= 0.9

## Installation

### lazy.nvim

```lua
{
  "MisakiForacy/musicode.nvim",
  config = function()
    require("musicode").setup({ mode = "flow" })
  end,
}
```

### packer.nvim

```lua
use({
  "MisakiForacy/musicode.nvim",
  config = function()
    require("musicode").setup({ mode = "flow" })
  end,
})
```

## Usage

```vim
:MusicodeToggle          " enable / disable
:MusicodeMode flow       " switch to flow mode
:MusicodeMode rhythm     " switch to rhythm-game mode
:MusicodeStats           " show session score / combo / accuracy
:MusicodeReset           " reset the session
```

Enter insert mode and start typing — judgment text (`PERFECT x12`, `GOOD`, ...) appears
at the end of the line.

### Statusline

```lua
-- e.g. with lualine
{ function() return require("musicode").statusline() end }
```

## Configuration

`setup()` accepts the following options (defaults shown):

```lua
require("musicode").setup({
  enabled = false,
  mode = "flow",            -- "flow" | "rhythm"
  capture = "insert",        -- "insert" (InsertCharPre) | "all" (every key in insert mode)
  flow = {
    ewma_alpha = 0.25,       -- smoothing for the cadence estimate
    perfect_ratio = 0.30,    -- within 30% of expected interval -> PERFECT
    good_ratio = 0.80,
    pause_ms = 1500,         -- longer gap -> thinking pause (breaks combo, no miss)
    min_interval_ms = 20,
  },
  rhythm = {
    bpm = 120,
    subdivisions = 4,        -- grid resolution per beat
    perfect_window_ms = 40,
    good_window_ms = 90,
    metronome = true,        -- audible tick (needs a non-"none" sound backend)
  },
  score = { perfect = 100, good = 50, combo_bonus = 5 },
  ui = { judgment = true, judgment_ttl_ms = 350 },
  sound = { backend = "none" },  -- "none" | "system" | "rpc"
})
```

### Sound backends

- `none` — visual only (default; zero latency, zero dependencies).
- `system` — Windows `[console]::beep` placeholder. Audible but high latency; for
  trying the feel only.
- `rpc` — reserved seam for the upcoming Rust audio daemon (low-latency samples and a
  real metronome). Set `require("musicode.sound").rpc_send` to your transport.

## Roadmap

- [x] Pure-Lua MVP: capture, dual-mode judgment, combo, judgment popups, statusline.
- [ ] Rust + cpal/rodio companion daemon over msgpack-RPC for <20ms audio.
- [ ] Local keystroke-rhythm logging (opt-in) and statistical adaptive tempo.
- [ ] Optional deep-learning personalization of cadence / adaptive difficulty.

## License

[MIT](./LICENSE)
