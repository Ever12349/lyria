# Lyria

个人本地音乐播放器（macOS / Apple Silicon）。仅本机曲库；人机面是原生窗口 + 菜单栏；agent 面以 MCP（server name `lyria`）为主，可选 loopback HTTP。

当前仓库状态：**静态 UI 壳样例已落地**（假数据，无真播放 / 无 MCP / 无 HTTP）。引擎与 agent 面需另说「开工」。

**Checkout 路径：** `/Users/qianxiao/worker/AIAgent/lyria`

## 文档与设计

| 资源 | 链接 |
| --- | --- |
| 文档索引 | [`docs/`](./docs/) |
| 全流程开发规格（Markdown） | [`docs/dev-spec.md`](./docs/dev-spec.md) |
| 交互式规格（Canvas） | [Lyria 全流程开发文档](https://cursor.com/canvas/store-669ca32f-ae0c-4bc0-be04-6e46150cff28/37c89944-4d8d-4256-b8f6-e516d782a9f4) |
| UI 设计稿 PNG | [`.design/ui-mocks/`](./.design/ui-mocks/)（01–14） |
| 窗口与壳层约定 | [`.design/docs/window-chrome.md`](./.design/docs/window-chrome.md) |
| Figma | [Lyria macOS UI](https://www.figma.com/design/JJFaj1UysoberBKEr8G8Jc) |

## 打开 / 运行

**推荐（Xcode）**

```bash
open /Users/qianxiao/worker/AIAgent/lyria/Lyria.xcodeproj
```

选 scheme **Lyria**，本机 Mac，⌘R。

**或直接打开已构建的 App**

```bash
open /Users/qianxiao/worker/AIAgent/lyria/Lyria.app
```

**命令行重编**

```bash
cd /Users/qianxiao/worker/AIAgent/lyria
swift build -c debug
cp .build/debug/Lyria Lyria.app/Contents/MacOS/Lyria
open Lyria.app
```

也可：`./scripts/run.sh`（前台跑二进制）。

## 窗口内容（静态壳）

- 左栏：曲库 / 艺人 / 专辑 / 播放列表 / 设置（曲库为实页，其余占位）
- 中栏：假曲目表；高亮行为「正在播放」
- 底栏：封面占位、曲名、进度、shuffle · prev · play/pause · next · repeat · 音量 · 队列（仅本地 `@State`）

Deep Space：背景 `#0a0b1a`，强调色 `#9b87f5 → #7c3aed`，圆角 16–24。

## 布局（Music 式）

- 左侧边栏通到窗口顶/底（玻璃铺进透明标题栏，红绿灯落在侧栏列内），**可拖拽改宽**（约 168–320，默认 ~228）
- 播放条只在右侧详情列底部，不横跨侧栏下方
- 曲库列表：外层卡片描边 + 行描边
- 原生透明标题栏 + 系统双击放大（`TitlebarPassthroughContentView` hitTest 穿透；无自定义 NSEvent zoom）

产品显示名与 MCP 名：**Lyria** / **`lyria`**。正式项目目录名：**`lyria`**。
