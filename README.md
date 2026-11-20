# Lyria

个人本地音乐播放器（macOS / Apple Silicon）。仅本机曲库；人机面是原生窗口 + 菜单栏；agent 面以 MCP（server name `lyria`）为主——客户端经 **stdio 薄桥**附着到已运行的 App 内唯一引擎（Unix socket：Application Support API → `Lyria/mcp.sock`；见 `docs/dev-spec.md`「MCP 进程模型」）；可选 loopback HTTP。

当前仓库状态：**主窗、曲库、播放引擎、阶段 3 MCP 和本地 HTTP 已落地。** 选择一个文件夹后扫描真实音频并写入 SQLite。设置里「允许经 MCP 控制」默认开，「本地 HTTP API」默认关，只听 `127.0.0.1:17890`。菜单栏还没做。启动不会自动扫描，也不会预置 `~/Music`；没选文件夹时设置显示「未选择」。个人 MVP **关** App Sandbox，仍写 `scan_roots.bookmark`。Bundle id 仍是 `local.lyria.sample`。

下文命令都在仓库根目录执行。

## 文档与设计

| 资源 | 链接 |
| --- | --- |
| 文档索引 | [`docs/`](./docs/) |
| 全流程开发规格（Markdown） | [`docs/dev-spec.md`](./docs/dev-spec.md) |
| 交互式规格（Canvas） | [Lyria 全流程开发文档](https://cursor.com/canvas/store-669ca32f-ae0c-4bc0-be04-6e46150cff28/37c89944-4d8d-4256-b8f6-e516d782a9f4) |
| UI 设计稿 PNG | [`.design/ui-mocks/`](./.design/ui-mocks/)（01–14） |
| HTML 原型（壳层视觉真源） | [`.design/ui-mocks/html/`](./.design/ui-mocks/html/)（结构真源；不要求像素级） |
| 窗口与壳层约定 | [`.design/docs/window-chrome.md`](./.design/docs/window-chrome.md) |
| Figma | [Lyria macOS UI](https://www.figma.com/design/JJFaj1UysoberBKEr8G8Jc) |

## 打开 / 运行

**推荐（Xcode）**

```bash
open Lyria.xcodeproj
```

选 scheme **Lyria**，本机 Mac，⌘R。曲库数据库在「应用程序支持 / Lyria / library.sqlite」（经 Application Support API 解析，不手写家目录字符串）。

**命令行重编（macOS）**

```bash
swift build -c debug
cp .build/debug/Lyria Lyria.app/Contents/MacOS/Lyria
open Lyria.app
```

Cursor 需要这份二进制的绝对路径，参数是 `--mcp`：

```json
{
  "mcpServers": {
    "lyria": {
      "command": "/绝对路径/lyria/Lyria.app/Contents/MacOS/Lyria",
      "args": ["--mcp"]
    }
  }
}
```

把 `command` 换成仓库里 `Lyria.app/Contents/MacOS/Lyria` 的绝对路径。`.build/debug/Lyria --mcp` 是同一份程序；`./scripts/run.sh` 跑的也是它。

也可：`./scripts/run.sh`（前台跑二进制）。`Package.swift` 在 macOS 上包含 App 目标；在 Linux 上只构建 `LyriaCore` 与 `LyriaTests`，因为壳层依赖 SwiftUI。

**核心单测**

```bash
swift test --filter LyriaTests
```

锁住 Crockford 全零向量（`trk_` + 22 个 `0`）、名称规范化和指纹 `full` / `head_tail_size` 分支。Xcode scheme **Lyria** 的 Test action 同样包含 `LyriaTests`。

## 窗口内容

- 左栏：12px 内缩圆角卡。曲库 / 艺人 / 专辑 / 全部播放列表 / 设置。全部播放列表下最多 5 个最近用过的播放列表
- 详情列：搜索（记住来源页）、page-head、曲库表、艺人/专辑/播放列表、设置、空态
- 曲库为空时显示「还没有音乐」，可以选文件夹或打开设置
- 空曲库「扫描曲目」或标题行「扫描文件夹」选择文件夹后增量扫描。标题行「添加曲目」把选中的音频文件入库，不改扫描根。设置里没有曲库路径和重新扫描。扫描或添加时任意页显示进度，可以取消
- 从曲库移除会删掉数据库里的曲目行（文件留在磁盘；指纹保留，再次导入仍是同一个 id）
- 播放列表可以新建、改名、删除、加歌、移出。还不能拖拽排序
- 底栏传输条可以播放、暂停、上一首、下一首，也可以拖动进度
- 队列浮层显示当前播放队列

Deep Space：背景 `#0a0b1a`，强调色 `#9b87f5 → #7c3aed`，圆角 16–24。

## 布局（Music 式）

- 侧栏是一张距窗口边缘 12px 的圆角卡，**可拖拽改宽**（约 168–320，默认 ~228）。红绿灯落在卡顶空白带里
- 播放条只在右侧详情列底部，圆角卡片，不伸进侧栏下方
- 曲目行：封面、标题、艺人、专辑、时长、更多。艺人或专辑没有 id 时，前往按钮不可用
- 原生透明标题栏 + 系统双击放大。`TitlebarPassthroughContentView` 只把**系统标题栏拖动带**交给系统，不再把整窗顶 52pt 一律穿透

对照 `.design/ui-mocks/html/`（`index.html`、`prototype.js`、`prototype.css`、`theme.css`，以及 01–14）。空曲库 / 空播放列表文案仍按规格。

产品显示名与 MCP 名：**Lyria** / **`lyria`**。正式项目目录名：**`lyria`**。
