# musicode.nvim

让写代码 / 写文像玩音游一样有节奏感。musicode 把你的每次击键变成实时连击与判定，
让敲键带上动量——专为有连贯敲键习惯的人打造，比如算法竞赛选手和网文写手。

> 状态：MVP（纯 Lua，零依赖）。低延迟音频将由配套的 Rust 守护进程提供，已列入路线图
> （`sound.backend = "rpc"`）。

## 特性

- **两种可切换模式**
  - `flow`（心流）—— 跟随*你自己*的节奏（对击键间隔做 EWMA 平滑）。长时间思考停顿
    只会中断连击，**不会**被判成 Miss。核心机制：**用持续敲击让背景音乐保持连贯，一断流音乐就暂停**。
  - `rhythm`（音游）—— 按固定 / 自适应 BPM 网格判定击键（PERFECT / GOOD / MISS），音乐连续播放、你去踩点。
- **节奏音乐**：播放你自备的（无版权）音频文件；flow 模式下由敲击驱动暂停/续播（从原位接续，保持连贯）。
- 连击计数、分数，以及实时 BPM 估算。
- 通过 extmark 在缓冲区行尾直接弹判定，带**闪光 + 星芒拖尾**动画（连击越高拖尾越长，`ui.effects` 可关）。
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
:MusicodeStats           " 查看本次的分数 / 连击 / 命中 / 节奏画像
:MusicodeReset           " 重置本次会话
:MusicodeLog [on|off]    " 开关本地击键节奏日志（默认关闭）
:MusicodeMusic [on|off|<file>]  " 开/关背景音乐，或指定音频文件（需 rpc 后端）
:MusicodeTrain           " 从本地节奏日志训练个人画像（个性化难度）
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
    pause_ms = 2000,         -- 间隔更长 -> 视为思考停顿（断连击，不判 Miss）
    min_interval_ms = 20,
    adaptive = true,         -- 按你的节奏稳定度自动调整判定容差
  },
  rhythm = {
    bpm = 120,
    subdivisions = 4,        -- 每拍的网格细分数
    perfect_window_ms = 40,
    good_window_ms = 90,
    metronome = true,        -- 节拍器滴答声（需要非 "none" 的音频后端）
    adaptive = true,         -- 按你的自然击键速度自动选择目标 BPM
  },
  score = { perfect = 100, good = 50, combo_bonus = 5 },
  ui = { judgment = true, judgment_ttl_ms = 350, effects = true },  -- effects: 闪光+星芒拖尾动画
  sound = { backend = "none", drums = true },  -- backend: "none"|"system"|"rpc"；drums: rpc 下按键拍点音（木琴/五声音阶）
  stats = { window = 200 },        -- 滚动节奏画像的样本窗口
  log = { enabled = false, flush_every = 50 },  -- 本地节奏日志（opt-in）
  music = {
    file = nil,             -- 你自备的（无版权）音频文件路径，需 rpc 后端
    volume = 70,            -- 前景（敲码时）音量 0..100
    background_volume = 15, -- 背景（停手时）音量；音乐始终播放、不暂停
    swell_ms = 500,         -- 敲码时从背景渐强到前景的时长
    gate = true,            -- flow 模式：敲击驱动音量渐强/渐弱
    tail_beats = 4,         -- 停手后按歌曲 BPM 再多播几拍才开始渐弱
    fade_min_ms = 2500,     -- 渐弱回背景的最短时长
    fade_max_ms = 10000,    -- 渐弱回背景的最长时长
    fade_per_combo_ms = 50, -- 渐弱时长随连击数增长（每连击 +50ms，封顶 fade_max_ms）
    idle_ms = 1200,         -- 无法得知 BPM 时的回退延时
    autostart = false,      -- enable 时若已配置 file 则自动开始
  },
  personalize = { enabled = true },  -- 启动时加载 profile.json，按技能初始化难度
  difficulty = {
    enabled = true,         -- 在线自适应难度：把判定窗口朝目标命中率自动收紧/放宽
    target_perfect = 0.55,  -- 目标 PERFECT 比例
    step = 0.04, min = 0.6, max = 1.8,
  },
})
```

### 音频后端

- `none` —— 仅视觉（默认；零延迟、零依赖）。
- `system` —— Windows `[console]::beep` 占位音。能出声但延迟高，仅用于体验手感。
- `rpc` —— 连接 Rust 音频守护进程（`daemon/`），低延迟实时音效 + 真正的节拍器。
  启用方式：先构建守护进程（见下），再 `setup({ sound = { backend = "rpc" } })`。

## 构建音频守护进程（可选，用于 `rpc` 后端）

需要 Rust 工具链（`cargo`）。在插件目录下执行：

```sh
cd daemon
cargo build --release
```

构建产物为 `daemon/target/release/musicode-daemon`（Windows 为 `.exe`）。插件会自动
发现它；如放在别处可用 `sound.daemon_cmd` 指定：

```lua
require("musicode").setup({
  sound = { backend = "rpc", daemon_cmd = { "/abs/path/to/musicode-daemon" } },
})
```

守护进程协议极简：Neovim 通过 stdin 按行发送事件——音效 `perfect` / `good` / `miss` /
`tick`，音乐控制 `music <路径>` / `musicpause` / `musicresume` / `musicstop` / `musicvol <0-100>`，
以及 `quit`。守护进程即时合成音效、解码并循环播放音频文件。若音频设备初始化失败，会静默降级而不影响编辑。

## 自适应 & 节奏日志

- **自适应判定（默认开启）**：musicode 维护一份滚动的击键节奏画像（`stats.window`）。
  - `flow.adaptive` —— 节奏越稳，PERFECT 窗口越严；越随性则越宽松，判定更公平。
  - `rhythm.adaptive` —— 攒够样本后，自动把目标 BPM 调成贴合你自然击键速度的值
    （节拍器与判定网格随之对齐）。
  - 用 `:MusicodeStats` 可查看样本数、间隔均值/中位数与当前自适应 BPM。
- **本地节奏日志（opt-in，默认关闭）**：`:MusicodeLog on` 或 `log.enabled = true` 开启后，
  击键节奏以 JSONL 追加写入 `stdpath("data")/musicode/rhythm.jsonl`（可用 `log.path` 自定义）。
  数据仅保存在本地，供后续统计与个性化训练使用。

## 个性化 & 自适应难度

- **个人节奏画像**：开启日志攒一段数据后，`:MusicodeTrain` 会从 `rhythm.jsonl` 学习你的
  击键画像（按文件类型的间隔中位数/标准差 + 命中率 → 技能值 `skill`），写入
  `stdpath("data")/musicode/profile.json`；启动时自动加载，并据 `skill` 初始化判定难度。
- **在线自适应难度**（`difficulty.enabled`）：游玩中持续把判定窗口朝 `target_perfect`
  自动**收紧/放宽**——打得越准越难，反之更宽松。`:MusicodeStats` 可看当前 `difficulty` 与 `skill`。
- **可选的离线训练器**：`train/train.py`（纯标准库）从 `rhythm.jsonl` 生成同构的
  `profile.json`，作为接入更重 / 神经网络模型的扩展点：
  ```sh
  python train/train.py
  python train/train.py --log path/rhythm.jsonl --out path/profile.json
  ```

## 节奏音乐（flow 模式核心）

flow 模式的核心玩法：**让音乐随你的敲击保持连贯**。

- 需要 `sound.backend = "rpc"`（已构建守护进程）并提供一个**你自备的、无版权**的音频文件。
- 设置 `music.file` 后用 `:MusicodeMusic on`（或 `:MusicodeMusic <文件>`）开始。
- flow 模式（音量包络）：背景音乐**始终播放**、平时较轻（`background_volume`）；连续敲码（含退格）时在
  `swell_ms`（≈0.5s）内**渐强**到前景音量（`volume`）；停手后按歌曲节奏再多播 `music.tail_beats` 拍，
  然后**缓缓退回背景音**——渐弱时长**随连击数增加**（`fade_min_ms`≈2.5s 起，每连击递增，封顶 `fade_max_ms`≈10s），
  连得越久退得越缓；其间一旦再敲键就重新渐强。
- rhythm 模式：音乐连续播放作为"曲子"，你按节拍踩点。
- **按键拍点音**：rpc 后端下，击键由守护进程合成**柔和的木琴 / 音乐盒音色（五声音阶）**。
  播放音乐时，**只有当击键落在歌曲真实鼓点（起音）附近时才出声**——加载音乐时即做起音检测（谱通量），
  并把检测结果写入 `<音频文件>.beats.json`（起音点列表 + 估计 BPM，可查看）；每次击键吸附到最近的真实鼓点，
  偏离则静音、音量较轻，是稀疏、不抢音乐的"踩准"反馈（即时、无延迟）。未播放音乐时回退到 BPM 估算网格。可用 `sound.drums = false` 关闭。
- 音频解码 / 循环由 Rust 守护进程完成，支持 mp3 / ogg / wav / flac。

> 版权说明：插件不内置任何音频；请使用你自己拥有合法使用权 / 无版权问题的文件。

## 路线图

- [x] 纯 Lua MVP：击键捕获、双模式判定、连击、判定弹窗、状态栏。
- [x] Rust + rodio/cpal 配套守护进程（基于行协议）实现低延迟音频与节拍器。
- [x] 本地击键节奏日志（opt-in）+ 统计式自适应 tempo。
- [x] 歌曲鼓点提取（谱通量起音检测，输出 `*.beats.json`）+ 按键拍点吸附到真实鼓点。
- [x] 个性化：从节奏日志学习个人画像（`:MusicodeTrain` / `train/train.py`）+ 在线自适应难度；可接入更重 / 神经模型。

## 许可证

[MIT](./LICENSE)
