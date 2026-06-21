# musicode.nvim

让写代码 / 写文像玩音游一样有节奏感。musicode 把你的每次击键变成实时连击与判定，
让敲键带上动量——专为有连贯敲键习惯的人打造，比如算法竞赛选手和网文写手。

> 状态：MVP（纯 Lua，零依赖）。低延迟音频将由配套的 Rust 守护进程提供，已列入路线图
> （`sound.backend = "rpc"`）。

## 特性

- **两种可切换模式**
  - `flow`（心流）—— 跟随*你自己*的节奏（对击键间隔做 EWMA 平滑）。长时间思考停顿
    只会中断连击，**不会**被判成 Miss。
  - `rhythm`（音游）—— 按固定 BPM 网格判定击键（PERFECT / GOOD / MISS），像真正的音游。
- 连击计数、分数，以及实时 BPM 估算。
- 通过 extmark 在缓冲区行尾直接弹判定（不额外开窗口）。
- 状态栏组件。
- 可插拔的音频后端（`none` / `system` / `rpc`）。

## 环境要求

- Neovim >= 0.9

## 安装

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

## 使用

```vim
:MusicodeToggle          " 开启 / 关闭
:MusicodeMode flow       " 切到心流模式
:MusicodeMode rhythm     " 切到音游模式
:MusicodeStats           " 查看本次的分数 / 连击 / 命中
:MusicodeReset           " 重置本次会话
```

进入插入模式开始打字——判定文字（`PERFECT x12`、`GOOD` 等）会出现在当前行行尾。

### 状态栏

```lua
-- 以 lualine 为例
{ function() return require("musicode").statusline() end }
```

## 配置

`setup()` 接受以下选项（下面是默认值）：

```lua
require("musicode").setup({
  enabled = false,
  mode = "flow",            -- "flow" | "rhythm"
  capture = "insert",        -- "insert"（InsertCharPre）| "all"（插入模式下的每个按键）
  flow = {
    ewma_alpha = 0.25,       -- 节奏估算的平滑系数
    perfect_ratio = 0.30,    -- 与预期间隔相差 30% 以内 -> PERFECT
    good_ratio = 0.80,
    pause_ms = 1500,         -- 间隔更长 -> 视为思考停顿（断连击，不判 Miss）
    min_interval_ms = 20,
  },
  rhythm = {
    bpm = 120,
    subdivisions = 4,        -- 每拍的网格细分数
    perfect_window_ms = 40,
    good_window_ms = 90,
    metronome = true,        -- 节拍器滴答声（需要非 "none" 的音频后端）
  },
  score = { perfect = 100, good = 50, combo_bonus = 5 },
  ui = { judgment = true, judgment_ttl_ms = 350 },
  sound = { backend = "none" },  -- "none" | "system" | "rpc"
})
```

### 音频后端

- `none` —— 仅视觉（默认；零延迟、零依赖）。
- `system` —— Windows `[console]::beep` 占位音。能出声但延迟高，仅用于体验手感。
- `rpc` —— 为即将到来的 Rust 音频守护进程预留的接口位（低延迟采样 + 真正的节拍器）。
  把你的传输实现赋给 `require("musicode.sound").rpc_send` 即可。

## 路线图

- [x] 纯 Lua MVP：击键捕获、双模式判定、连击、判定弹窗、状态栏。
- [ ] Rust + cpal/rodio 配套守护进程，经 msgpack-RPC 实现 <20ms 音频。
- [ ] 本地击键节奏日志（opt-in）+ 统计式自适应 tempo。
- [ ] 可选的深度学习个性化：节奏预测 / 自适应难度。

## 许可证

[MIT](./LICENSE)
