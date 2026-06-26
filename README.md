# musicode.nvim

让写代码 / 写文像玩音游一样有节奏感：每次击键都有实时连击与判定特效。`flow`（心流）模式让背景音乐随你的连续敲击渐强、停手渐弱；`rhythm`（音游）模式按节拍踩点。专为算法竞赛选手、网文写手这类有连贯敲键习惯的人打造。

> 纯视觉判定零依赖即可用；想要音效 / 背景音乐 / 鼓点，需装 Rust（`cargo`）编译配套守护进程，并设 `sound.backend = "rpc"`。

## 特性

- 两种模式：`flow`（跟随你自己的节奏，停顿不判 Miss）/ `rhythm`（按 BPM 踩点）。
- 背景音乐随敲击渐强、停手渐弱（flow），或连续播放供踩点（rhythm）。
- 自定义曲库：每首音频自动提取鼓点；支持顺序 / 随机 / 单曲循环、列表选曲。
- 击键拍点音对齐歌曲真实鼓点；闪光 + 星芒拖尾的判定动画。
- 连击 / 分数 / 状态栏；可按你的习惯自适应难度。

## 安装

需要 Neovim ≥ 0.9。音效 / 音乐 / 鼓点需要 Rust（`cargo`）；纯视觉则不需要。

### lazy.nvim（含音频）

```lua
{
  "MisakiForacy/musicode.nvim",
  build = "cd daemon && cargo build --release",
  config = function()
    require("musicode").setup({
      enabled = true,
      mode = "flow",
      sound = { backend = "rpc" },
      music = {
        library = "/你的本地音乐文件夹",
        autostart = true,
      },
    })
  end,
}
```

### lazy.nvim（纯视觉，零依赖）

```lua
{ "MisakiForacy/musicode.nvim", config = function()
    require("musicode").setup({ enabled = true })
  end }
```

> - 用本地副本：把仓库名换成 `dir = "/绝对/路径/musicode"` 并加 `name = "musicode"`。
> - 没装 Rust 也能用，保持 `sound.backend = "none"`（纯视觉）。

## 命令

```vim
:MusicodeToggle                " 开启 / 关闭
:MusicodeMode flow|rhythm       " 切换模式
:MusicodeMusic [on|off|<file>]  " 开关 / 指定背景音乐
:MusicodeNext / :MusicodePrev   " 切歌
:MusicodePick                   " 列表选曲
:MusicodeOrder [sequence|shuffle|repeat_one]  " 播放顺序
:MusicodeVolume [fg] [bg]       " 调音量（加强音 / 背景音）
:MusicodeStats                  " 查看分数 / 连击 / 状态
:MusicodeViz                    " 开关右下角频谱可视化（默认启动）
:MusicodeLibrary                " 扫描曲库并提取鼓点
:MusicodeTrain                  " 从本地日志学习个人难度（需先 :MusicodeLog on）
```

## 常用配置

```lua
require("musicode").setup({
  enabled = true,
  mode = "flow",                 -- "flow" | "rhythm"
  sound = { backend = "rpc" },   -- "none"(纯视觉) | "rpc"(音频)
  music = {
    library = "/你的本地音乐文件夹",
    autostart = true,
    order = "shuffle",           -- "sequence" | "shuffle" | "repeat_one"
    volume = 30,                 -- 强音量 0..100
    background_volume = 10,      -- 弱音量（自动 = 强音量 / 3）
  },
})
```

更多可调项（判定容差、淡出时长、自适应难度等）见 `setup` 的默认值。

## 状态栏（可选）

```lua
{ function() return require("musicode").statusline() end }  -- 以 lualine 为例
```

> 插件不内置任何音频；请使用你自己拥有合法使用权的音乐文件。

## 许可证

[MIT](./LICENSE)
