# Lyria 文档索引

Checkout：`/Users/qianxiao/worker/AIAgent/lyria`

- 交互式全流程规格（Canvas）：[Lyria 全流程开发文档](https://cursor.com/canvas/store-669ca32f-ae0c-4bc0-be04-6e46150cff28/37c89944-4d8d-4256-b8f6-e516d782a9f4)
- 仓库内 Markdown 规格：[`docs/dev-spec.md`](./dev-spec.md)
- 每个按钮的操作和限制：[控件操作与限制](./dev-spec.md#控件操作与限制)
- 窗口与壳层约定：[`../.design/docs/window-chrome.md`](../.design/docs/window-chrome.md)
- UI 设计稿 PNG：[`../.design/ui-mocks/`](../.design/ui-mocks/)（01–14）
- **HTML 原型 = 壳层视觉真源（文档约定）：** [`../.design/ui-mocks/html/`](../.design/ui-mocks/html/)；Swift 壳跟踪其结构；不要求像素级 — 见 [`dev-spec.md`](./dev-spec.md)#设计稿对照
- Figma：[Lyria macOS UI](https://www.figma.com/design/JJFaj1UysoberBKEr8G8Jc)
- MCP 进程模型（已锁定：薄桥 + 单实例；socket 经 Application Support API → `Lyria/mcp.sock`；死 sock unlink；桥 ≤3s 退避；无实例带窗拉起）：见 [`dev-spec.md`](./dev-spec.md)#mcp-进程模型已锁定
- 其它已锁决策（指纹阈值、encoding_suspect 仅 U+FFFD、`alb_`=艺人+专辑、iCloud≠tombstone、aliases 必持久化、oneShot `id:null`、阶段 3 不含菜单栏、`POST /play` XOR、系统 SQLite3、单根、登录项阶段门闩、Crockford 全零向量、有声人工门闩）。`user_hidden` 已在 2026-11-09 取消：见 [`dev-spec.md`](./dev-spec.md) 文首覆盖与「风险与未决」
- **C1 阶段 1 试播入口（已锁）：** 菜单「试播…」→ `NSOpenPanel` → `QueueItem.oneShot` / `play(uri: file://…)`；不入库、不另开 path-only API — [`dev-spec.md`](./dev-spec.md)#播放引擎
- **C2 App Sandbox（已锁：关）：** 个人 MVP 关闭沙盒；`scan_roots.bookmark` 仍从 day one 写 — [`dev-spec.md`](./dev-spec.md)#风险与未决
- **阶段 1 Amb-1…19（已锁 · 文档 only）：** 音量 1.0、`NowPlaying`、错误码六件套、`@Observable`、`Sources/Lyria/Engine/`、传输绑引擎、2–4 Hz、Alert+lastError、Queue 仅当前项、actor→MainActor、删 subtitle、无 LyriaCore、bundle sample、菜单试播、轻量标签、MVP UTType、ended→pause、状态存 ms、启动无假 nowPlaying；Amb-20 延后 — [`dev-spec.md`](./dev-spec.md)#阶段-1-已锁决策amb-119--用户确认全部按照建议
- **Amb-UI-1…16（已锁 · 文档 only）：** 主窗全分区假数据可点；Spec 空态文案；Dreamscape FakeData；假队列；三栏传输；封面/更多假动作；侧栏圆角卡；完整 page-head；设置六行 stub；repeat 三态；UI 阶段假 now-playing；搜索+returnTo；pill toast；HTTP stub 显示关；仅 SF Symbols；无真 MenuBarExtra — [`dev-spec.md`](./dev-spec.md)#ui-已锁决策amb-ui-116--用户确认全部按照建议
- Standing hold：**引擎 / MCP / HTTP / MenuBarExtra** 仍须另说开工。**2026-11-09 曲库切片已开工，且阶段 2 先于阶段 1。**
- **曲库切片覆盖：** 不预置 `~/Music`，启动不自动扫描；扫描入口是空曲库「扫描曲目」，设置里没有路径/重扫行；进度在曲库页，可取消；取消保留已入库行并 toast「已取消扫描」；取消 `user_hidden`，从曲库移除是硬删除 `tracks` 行并保留 `fingerprints`；播放控件本切片置灰；`encoding_suspect` 只认 U+FFFD；扫描并发 4；清除指纹用 `NSAlert`
