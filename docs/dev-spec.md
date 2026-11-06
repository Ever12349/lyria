# Lyria 全流程开发文档

个人本地音乐播放器 **Lyria**（macOS / Apple Silicon）从产品边界、架构、曲目 id、曲库、引擎、窗口壳层、UI、MCP/HTTP 到分阶段验收的完整技术规格。

> **Standing hold（已部分放行）**  
> 用户已对「静态壳样例」说开工：允许在 `/Users/qianxiao/worker/AIAgent/lyria` 迭代 macOS 窗口壳 + 侧栏/曲库/传输条假数据，贴齐 Deep Space 与下文窗口逻辑。完整播放引擎、曲库扫描、MCP、HTTP、真机验收仍须另说「开工」后才写。  
> 设计资产在仓库 `.design/`（UI mocks、窗口约定）。交互式规格见 [Canvas](https://cursor.com/canvas/store-669ca32f-ae0c-4bc0-be04-6e46150cff28/37c89944-4d8d-4256-b8f6-e516d782a9f4)。

**目录**

- [产品边界](#产品边界)
- [架构总览](#架构总览)
- [模块与目录](#模块与目录)
- [曲目与实体 id](#曲目与实体-id)
- [曲库扫描](#曲库扫描)
- [持久化 schema](#持久化-schema)
- [播放引擎](#播放引擎)
- [窗口与壳层逻辑](#窗口与壳层逻辑)
- [UI / IA](#ui--ia)
- [视觉 token 与还原底线](#视觉-token-与还原底线)
- [空态与错误态](#空态与错误态)
- [MCP schema](#mcp-schema)
- [HTTP API](#http-api)
- [设置](#设置)
- [开发阶段](#开发阶段)
- [验收标准](#验收标准)
- [风险与未决](#风险与未决)

---

## 产品边界

| 项 | 值 |
| --- | --- |
| 产品 | Lyria — 个人本地音乐播放器；仅本机曲库，无云同步、无流媒体账号 |
| 目标机 | Mac · Apple M1 Pro · my-notebook-2.local |
| 仓库路径 | `/Users/qianxiao/worker/AIAgent/lyria`（正式项目目录；品牌与文件夹均为 Lyria / lyria） |
| GitHub remote | 计划私有仓 `Ever12349/lyria`；创建/推送由用户或主流程确认，勿臆造 URL、勿在未授权时创建 |
| 技术栈 | macOS-native Swift · SwiftUI + 必要处 AppKit · 音频用 AVFoundation |
| 人机面 | macOS 主窗口（标题 Lyria）+ 菜单栏 MenuBarExtra（不是设计参考里的移动双 Tab 壳） |
| Agent 面 | MCP 为主（stdio，server name `lyria`，直连播放引擎）；本地 HTTP 可选同能力层 |
| 证明完成 | 真机播放真实文件 + 至少一条 agent 调用路径（优先 MCP） |
| 非目标 | 截图操控桌面、跨机分享曲库、云歌词、DRM 商店 |

**同名品牌说明：** 另有设计参考工程亦名 Lyria，路径 `/Users/qianxiao/worker/reactactive/Lyria`（含 Figma Deep Space）。那是视觉/交互参考应用；本文档描述的是本仓库的 macOS 本地播放器产品，同样品牌名为 Lyria。二者同品牌、不同工程，勿混为同一仓库。

两个表面共用一套引擎状态：人在窗口/菜单栏操作，agent 经 MCP（或可选 HTTP）改同一 TransportState / Queue。关掉 HTTP 不得影响 MCP。Agent 接口是 MCP/HTTP 工具，不是截图或桌面驱动。

---

## 架构总览

进程内单引擎：LibraryIndex 管指纹与元数据；PlaybackEngine 管 AV 解码与时钟；Queue + TransportState 是唯一真相源；MCPServer 与可选 HTTPServer 都只调引擎，互不代理。

```text
SwiftUI App (Lyria 窗口 + MenuBarExtra)
MCPServer (stdio · name lyria)
HTTPServer (可选 · 127.0.0.1:17890)
        │
        ▼
TransportState + Queue   ← 唯一真相源
        │
   ┌────┴────┐
   ▼         ▼
PlaybackEngine     LibraryIndex
(AVFoundation)     (扫描 · 指纹 · SQLite)
   │               │
   ▼               ▼
本地音频文件     Application Support/Lyria
(用户配置文件夹)  (library.sqlite · artwork)
```

MCP 不要求也不应默认代理 HTTP；两者并列挂在同一状态机上。HTTP 关闭后 MCP 仍完整可用。

---

## 模块与目录

建议 SPM + Xcode macOS App 目标。包名与可执行目标优先 Lyria（CFBundleDisplayName / 窗口标题均为 Lyria）；MCP 作为同进程内嵌服务，不另起 CLI（调试可用 `--mcp` 前台 stdio）。

当前静态壳样例源码在 `Sources/Lyria/`；下列为完整产品目标结构（引擎/MCP 开工后再铺齐）。

| 路径 | 职责 |
| --- | --- |
| `App/` | LyriaApp、主窗口 Scene、MenuBarExtra |
| `App/Views/` | Shell、曲库表、艺人/专辑/歌单页、设置、空态组件 |
| `App/Theme/` | Deep Space 色板、圆角、玻璃材质 token |
| `Engine/PlaybackEngine.swift` | AV 会话、当前项、seek、音量 |
| `Engine/TransportState.swift` | playing、position、shuffle、repeat、volume 可观察状态 |
| `Engine/Queue.swift` | 有序列表、next/previous、插队 |
| `Library/LibraryIndex.swift` | 扫描调度、增量策略 |
| `Library/Fingerprint.swift` | SHA-256 / 头尾兜底、Crockford Base32、`trk_` 生成 |
| `Library/MetadataReader.swift` | AVAsset 标签与封面 |
| `Library/Models.swift` | Track / Artist / Album / Playlist 值类型 |
| `Persistence/Database.swift` | SQLite 打开、迁移 |
| `Persistence/Schema.sql` | 表定义 |
| `Agent/MCPServer.swift` | stdio JSON-RPC MCP · name `lyria` · tools 注册 |
| `Agent/HTTPServer.swift` | 可选 loopback HTTP · 可整段禁用 |
| `Agent/APISchemas.swift` | 与 HTTP/MCP 共用的请求响应 Codable |

**依赖边界：** Views 只依赖 TransportState / Library 查询接口；Agent 层禁止 import SwiftUI；Fingerprint 无 AV 依赖，便于单测。

**设计与文档资产（已落地）：**

| 路径 | 内容 |
| --- | --- |
| `.design/ui-mocks/` | 全套界面 PNG（01–14）与 `html/` 源 |
| `.design/docs/window-chrome.md` | 窗口与标题栏实现契约 |
| `docs/dev-spec.md` | 本文档 |
| `docs/README.md` | 文档索引 |

---

## 曲目与实体 id

> **已锁定** — 用户确认「就按这套」，实现不得改格式或生成策略。前缀 `trk_` / `art_` / `alb_` / `pls_` 不因品牌更名而改变。

| 项 | 值 |
| --- | --- |
| 曲目格式 | `trk_` + 22 位 Crockford Base32（约 128 bit，URL 安全） |
| 示例 | `trk_01J9X2K4M7NQP8RSTUVWXY` |
| 同形前缀 | 艺人 `art_` · 专辑 `alb_` · 播放列表 `pls_` |

### 生成与稳定

1. 首次入库：内容指纹 = 文件整文件 SHA-256，取前 16 字节 → Crockford Base32 → 加 `trk_` 前缀。
2. 大文件兜底：`hash(头 64KB + 尾 64KB + 文件大小)`；写入指纹记录时注明用了 `full` 还是 `head_tail_size`。
3. 持久化 fingerprint → id 映射；同一指纹复用同一 id（去重）。
4. 路径是属性：路径变、指纹不变 → 更新 path，不换 id。
5. 文件缺失：id 保留为 tombstone；队列/歌单显示「文件缺失」；指纹再现 → 复活同一 id。
6. 硬链/拷贝：合并为一条曲目；MVP 只保留一条主 path（aliases 可后期）。
7. 仅改标签、内容不变：id 不变，刷新元数据。
8. 清空指纹库 = 换库；设置里单独警告。

### 禁止

- 路径字符串当 id
- inode 当长期 id
- 对外暴露自增数字 id

### API 约定

所有 `play` / `queue_add` / 列表项只认 `trk_…`。`POST /play` 可附带 `{ uri: "file://…" }` 作一次性点播，不写入曲库 id。曲目对象固定字段：`id` · `path` · `title` · `artist` · `album` · `durationMs` · `missing?`（可选 bool）。

### Crockford Base32 实现要点

字母表：`0123456789ABCDEFGHJKMNPQRSTVWXYZ`（排除 I L O U）。编码 16 字节 → 26 个 5-bit 组需补零到 130 bit，取前 22 个字符（固定输出长度 22）。解码时大小写不敏感；遇到 `I→1`、`L→1`、`O→0`、`U` 拒绝。单元测试锁定已知向量：给定 16 字节全零 → 固定 22 字符串，防止实现漂移。

---

## 曲库扫描

| 项 | 值 |
| --- | --- |
| 默认根目录（提议） | `~/Music`；设置里可改；多文件夹若实现干净则允许 |
| 格式 | AVFoundation 能播的：mp3、m4a/aac、aiff、wav；flac 视系统/框架可用性，见风险 |
| 元数据 | 优先 AVAsset / AVMetadataItem；封面嵌在文件或同目录 `folder.jpg` / `Cover.jpg` |
| 增量（提议） | 按 path + size + mtime 快路径；变更或新文件再算指纹校验 |
| 全量 | 设置提供「重新扫描」按钮，强制重走指纹（不无故换 id） |

### 扫描步骤

1. **枚举** — 对每个库根递归；跳过隐藏与已知非音频扩展名；尊重书签/安全作用域（若开沙盒则保存 security-scoped bookmark）。
2. **快路径** — path 已在库且 size+mtime 未变 → 跳过指纹；否则进入指纹。
3. **指纹与 upsert** — 算指纹；查 map；命中则更新 path/元数据；未命中则分配新 `trk_` 并写 map。
4. **tombstone** — 本轮未见的 path：标记 missing；不删 id；播放时拒绝并表面错误。
5. **艺人/专辑聚合** — 按规范化 artist/album 字符串生成或复用 `art_` / `alb_`（提议：对规范化名做 SHA-256 前 16 字节同算法，与曲目指纹独立命名空间）。

扫描在后台 Task 跑；UI 显示进度百分比与「正在扫描…」。扫描中允许播放已索引曲目。冲突同指纹多路径：保留首次主 path，日志记 aliases（MVP 可不展示）。

---

## 持久化 schema

根目录：`~/Library/Application Support/Lyria/`。主库 `library.sqlite`；封面缓存 `Artwork/trk_….jpg`（或按 hash 分片）。设置也落在同一 SQLite 的 `settings` 表，避免散落 plist 双源。

| 表 | 列（要点） |
| --- | --- |
| `fingerprints` | `fingerprint TEXT PRIMARY KEY` · `track_id TEXT NOT NULL UNIQUE` · `method TEXT (full\|head_tail_size)` · `created_at` |
| `tracks` | `id TEXT PK` · `path` · `title` · `artist_name` · `album_name` · `artist_id` · `album_id` · `duration_ms` · `size` · `mtime` · `missing INTEGER` · `updated_at` |
| `artists` | `id TEXT PK` · `name` · `sort_name` · `track_count` |
| `albums` | `id TEXT PK` · `name` · `artist_id` · `year` · `track_count` · `artwork_path` |
| `playlists` | `id TEXT PK` · `name` · `created_at` · `updated_at` |
| `playlist_tracks` | `playlist_id` · `track_id` · `position INTEGER` · `PK(playlist_id, position)` |
| `settings` | `key TEXT PK` · `value TEXT`（JSON 或标量字符串） |
| `scan_roots` | `id INTEGER PK` · `path TEXT UNIQUE` · `bookmark BLOB` · `enabled` |

迁移用整数 `user_version`；v1 即上表。清空指纹库 = `DELETE fingerprints` + 相关 tracks 并警告；歌单里的 id 会变 orphan，UI 标缺失。WAL 模式。备份：用户可复制整个 `Application Support/Lyria` 目录。

---

## 播放引擎

> **推荐选型** — 使用 `AVPlayer` + `AVPlayerItem`（非 `AVAudioPlayer`）。理由：统一 seek/状态 KVO、便于间隙无损换曲、支持更多容器；音量用 `AVPlayer.volume`；仅在未来加 EQ 时再上 `AVAudioEngine`。

| 项 | 值 |
| --- | --- |
| 会话 | playback 类别；macOS 用默认输出设备 |
| 时钟 | `addPeriodicTimeObserver` 约 2–4 Hz 推 `positionMs` 到 TransportState |
| 换曲 | `replaceCurrentItem`；ended 通知 → `Queue.next` 依 repeat/shuffle |
| shuffle | 维护打乱序索引表，不破坏原始 queue 顺序以便关闭 shuffle 恢复 |
| repeat | `off` \| `all` \| `one` 循环；`one` 在 ended 时 `seek(0)` 再 play |
| 缺失/不可播 | 不假装成功；抛错给 UI toast + MCP/HTTP error body |

**TransportState**（`@Observable` / `ObservableObject`）字段：`current Track?` · `playing` · `positionMs` · `durationMs` · `shuffle` · `repeatMode` · `volume` · `queueCount` · `engineAvailable`。所有表面只绑这份状态。

> 引擎尚未开工：静态壳仅有假数据传输条；真播放需另说「开工」。

---

## 窗口与壳层逻辑

> **已锁定** — 产品壳是 macOS 原生窗口，不是 Electron，也不是 Grok Bot 自定义 chrome。行为对齐系统「音乐」的标题栏与分栏，不是逐行复刻「音乐」源码。仓库内短文：[`.design/docs/window-chrome.md`](../.design/docs/window-chrome.md)。

| 项 | 值 |
| --- | --- |
| 窗口类型 | `NSWindow` · `styleMask = titled \| closable \| miniaturizable \| resizable \| fullSizeContentView` |
| 标题栏 | `titlebarAppearsTransparent = true` · `titleVisibility = .hidden` · `titlebarSeparatorStyle = .none` |
| 红绿灯 | 系统按钮；视觉上落在左侧栏内部（侧栏玻璃/底色通顶到窗口上缘，压在透明标题栏下） |
| 拖动 / 双击 | 原生 `NSThemeFrame`：拖动与双击放大/还原由系统处理；禁止自定义 `NSEvent` 监视器，禁止自调 `performZoom` |
| SwiftUI 补丁 | `TitlebarPassthroughContentView`：顶约 52pt `hitTest` 返回 `nil`，避免 SwiftUI 内容吃掉标题栏点击 |
| 侧栏宽度 | 可拖 168–320，理想约 228 |
| 分栏 | 左侧栏通窗高（贴底，与传输条并排到窗口底）；详情列 = 搜索 + 页面内容 + 底栏传输；传输条不伸进侧栏下方 |
| 色板 | Deep Space：bg `#0a0b1a` · accent `#9b87f5 → #7c3aed`；左右同一 Deep Space 底色；禁用 behindWindow vibrancy（会吸桌面壁纸色调） |
| 曲目列表 | 带边框的列表卡片 + 可见行描边 |

**实现备注：** 当前静态样例用 `HStack` + `SidebarResizeHandle` 替代 `NavigationSplitView`，以实现「红绿灯落在侧栏内」与侧栏拖宽；文档锁定的是行为与布局，具体控件可演进。队列不是永久第三列，而是详情区内可选浮层/面板。

---

## UI / IA

壳层对齐「窗口与壳层逻辑」：左导航通窗高；右详情列含顶搜索、页面内容、底传输条。导航项：曲库 · 艺人 · 专辑 · 播放列表 · 设置。队列为详情区内可选浮层/面板，不是常驻第三列。窗口标题与菜单栏品牌文案为 Lyria。

| 页面 | 内容 |
| --- | --- |
| 曲库 | 带边框列表卡片；行：标题/艺人/专辑/时长 + 可见行描边；双击播放；右键加入队列/歌单 |
| 艺人 | 网格 → 详情：专辑横滑 + 热门曲目 |
| 专辑 | 网格 → 详情：播放全部 / 随机 / 加入队列 + 曲目列表 |
| 播放列表 | 网格 + 新建 → 详情：播放全部 / 随机 / 编辑 / 删除 + 可拖拽曲目 |
| 设置 | 见「设置」节 |
| 空态 / 错误态 | 空曲库、空歌单、搜索无结果、不可播、引擎不可用、文件缺失 — 见「空态与错误态」 |

### 传输条

仅在详情列底部：封面 · 标题/艺人 · 进度条（seek）· shuffle · 上一首 · 播放/暂停 · 下一首 · repeat（off\|all\|one）· 音量 · 队列开关。不跨侧栏。无当前曲时置灰。样式倾向圆角卡片，贴 Deep Space。

### 菜单栏

MenuBarExtra 弹出：封面 / 进度 / 传输 / 短队列（前若干首）。与主窗口共享 TransportState。

### 设计稿对照

| 帧 | 文件 |
| --- | --- |
| 曲库 | `.design/ui-mocks/01-library.png` |
| 艺人 | `.design/ui-mocks/02-artists.png` |
| 艺人详情 | `.design/ui-mocks/03-artist-detail.png` |
| 专辑 | `.design/ui-mocks/04-albums.png` |
| 专辑详情 | `.design/ui-mocks/05-album-detail.png` |
| 播放列表 | `.design/ui-mocks/06-playlists.png` |
| 播放列表详情 | `.design/ui-mocks/07-playlist-detail.png` |
| 设置 | `.design/ui-mocks/08-settings.png` |
| 空曲库 | `.design/ui-mocks/09-empty-library.png` |
| 空歌单 | `.design/ui-mocks/10-empty-playlist.png` |
| 搜索无结果 | `.design/ui-mocks/11-search-empty.png` |
| 队列 | `.design/ui-mocks/12-queue.png` |
| 菜单栏弹出 | `.design/ui-mocks/13-menubar.png` |
| 窗口注解 | `.design/ui-mocks/14-window-chrome.png` |

Figma：[Lyria macOS UI](https://www.figma.com/design/JJFaj1UysoberBKEr8G8Jc)

---

## 视觉 token 与还原底线

视觉参考工程亦名 Lyria（`/Users/qianxiao/worker/reactactive/Lyria`）与其 Deep Space 设计；参考 Figma：https://www.figma.com/design/03wRSSJiiPqcdZI3hiEsmn/Lyria 。那是设计参考；本产品是同品牌的 macOS 本地播放器，形态仍是窗口 + 菜单栏，不套用参考工程的移动双 Tab。本仓库交付稿见 Figma `JJFaj1UysoberBKEr8G8Jc` 与 `.design/ui-mocks/`。

| Token | 值 |
| --- | --- |
| 背景 | `#0a0b1a` |
| 强调色 | `#9b87f5 → #7c3aed`（渐变/悬停） |
| 圆角 | 16–24px |
| 材质 | 侧栏/卡片用 Deep Space 实色或同色玻璃；禁止 behindWindow vibrancy（会吸壁纸色）；左右同底色 `#0a0b1a` |
| 曲目列表 | 外框卡片 + 可见行描边（勿用近透明描边导致「边框消失」） |

字体跟随系统 SF；列表次要信息降低对比；封面圆角略小于卡片。深色为默认；设置里外观说明写死 Deep Space（MVP 不做多主题切换）。

> **视觉还原底线（已锁定）** — 尽量贴近设计；不承诺与参考 Lyria Web/Figma 像素级一致。SwiftUI 优先；毛玻璃、细阴影等难贴处允许 AppKit 补刀（如 `NSVisualEffectView`）。验收：同场景截图对照草图/参考，差一大截改 token 与布局，不硬撑。

---

## 空态与错误态

| 场景 | 表现 |
| --- | --- |
| 空曲库 | 文案「还没有音乐」· CTA「选择文件夹」/「打开设置」· 底栏无曲时置灰 |
| 空播放列表 | 「播放列表是空的」· CTA「添加歌曲」 |
| 搜索无结果 | 列表区空态文案，无假数据 |
| 无法播放此格式 | 行内警示 + toast；MCP/HTTP 返回明确 error，不假装成功 |
| 引擎/Agent 接口不可用 | 顶栏横幅「Agent 接口暂不可用 · 重试」；工具调用返回明确错误 |
| 文件缺失 | 队列/歌单行标「文件缺失」；播放拒绝 |

---

## MCP schema

| 项 | 值 |
| --- | --- |
| 名称 | `lyria` |
| 传输 | stdio MCP；进程内直连引擎（不强制经 HTTP） |
| 错误 | 引擎宕机/缺文件/坏参数 → 明确错误；永不假成功 |
| 不做 | 截图、桌面驱动类工具 |

| 工具 | 参数 | 说明 |
| --- | --- | --- |
| `lyria_status` | — | 当前曲、playing、位置/时长、shuffle、repeat、volume、队列长度 |
| `lyria_play` | `id?` | 有 id 播放该曲；无 id = resume |
| `lyria_pause` | — | 暂停；重复调用幂等返回当前状态 |
| `lyria_toggle` | — | 播放/暂停切换 |
| `lyria_next` | — | 下一首 |
| `lyria_previous` | — | 上一首 |
| `lyria_seek` | `positionMs` | 毫秒 seek |
| `lyria_shuffle` | `enabled: bool` | 幂等 |
| `lyria_repeat` | `mode: off\|all\|one` | 幂等 |
| `lyria_search` | `q` · `limit?` | 搜曲库 |
| `lyria_queue_list` | — | 当前队列 |
| `lyria_queue_add` | `id` · `position?: next\|end` | 入队 |
| `lyria_queue_clear` | — | 清空队列 |

响应 JSON 与 HTTP 同形。`lyria_status` 示例字段含 `ok`、`track`（id/title/artist/album/durationMs/missing?）、`playing`、`positionMs`、`durationMs`、`shuffle`、`repeat`、`volume`、`queueLength`。`lyria_play` 失败示例：`error=not_found`，`message=track id not in library`。客户端用 stdio 配置指向 Lyria App 的 MCP 入口（开工后写具体 launch 参数）。

> MCP 尚未开工：需另说「开工」后再实现。

---

## HTTP API

| 项 | 值 |
| --- | --- |
| 默认 | `http://127.0.0.1:17890` · 仅 loopback |
| 格式 | JSON；错误体含 `error` 与 `message` 字段，并带合适 HTTP 状态 |
| 幂等 | 重复 pause / 相同 shuffle 返回当前状态，不报错 |
| 鉴权 | loopback 无鉴权；若将来开 LAN 必须 token |
| 可关 | 设置关闭 HTTP 不影响 MCP |

| 方法 | 路径 | 体 / 查询 | MVP |
| --- | --- | --- | --- |
| GET | `/health` | → ok, version（产品名 Lyria） | 是 |
| GET | `/status` | 当前传输全量 | 是 |
| POST | `/play` | `id?` 或 `uri?`；空 = resume | 是 |
| POST | `/pause` | — | 是 |
| POST | `/toggle` | — | 是 |
| POST | `/next` | — | 是 |
| POST | `/previous` | — | 是 |
| POST | `/seek` | `positionMs` | 是 |
| POST | `/shuffle` | `enabled` | 是 |
| POST | `/repeat` | `mode` | 是 |
| POST | `/volume` | `level 0..1` | 可选 |
| GET | `/library/search` | `q=` | 是 |
| GET | `/library/tracks` | `limit` & `offset` | 批次 2 |
| GET | `/library/artists` | 列表 | 批次 2 |
| GET | `/library/artists/:id` | 详情 | 批次 2 |
| GET | `/library/albums` | 列表 | 批次 2 |
| GET | `/library/albums/:id` | 详情 | 批次 2 |
| GET | `/library/playlists` | 列表 | 批次 2 |
| GET | `/library/playlists/:id` | 详情 | 批次 2 |
| GET | `/queue` | — | 是 |
| POST | `/queue` | `id` · `position?: next\|end` | 是 |
| DELETE | `/queue` | 清空 | 是 |
| DELETE | `/queue/:index` | 按索引删 | 可选 |

MVP HTTP = health + status + 传输六件套（play/pause/toggle/next/previous/seek）+ shuffle/repeat + search + queue 读写。浏览类列表进批次 2。`file://` uri 点播不创建库 id。端口 `17890` 不变。

> HTTP 尚未开工；可关且不得拖垮 MCP。

---

## 设置

- 曲库路径（可多根，若实现干净）+ 「重新扫描」
- HTTP API 开/关 · 端口 · 复制 Base URL
- 登录时启动（LaunchAgent / SMAppService）
- 外观说明：Deep Space（MVP 只读说明）
- 危险区：清空指纹库（二次确认文案写明「旧 id 全部失效」）

---

## 开发阶段

静态壳样例已放行并在 `/Users/qianxiao/worker/AIAgent/lyria` 落地（侧栏通顶、红绿灯落侧栏内、曲库边框、Deep Space 同底色、原生双击放大、侧栏拖宽）；假数据，无真播放/无 MCP。引擎与 agent 面仍待另说开工。每阶段结束有可验证产物再进下一阶段。

| # | 阶段 | 状态 | 备注 |
| --- | --- | --- | --- |
| 0 | Scaffold Xcode/SPM macOS App（Lyria） | **已完成** | 静态壳样例已在 `lyria`；完整工程结构可继续收 |
| 0b | 静态壳视觉与窗口逻辑 | **已完成** | Music 式标题栏行为 + Deep Space；细节可继续抠 |
| 1 | Engine + 本地文件试播烟雾 | 待开工 | 另需开工 · AVPlayer 播一首真实文件 |
| 2 | Library 扫描 + 指纹/id DB | 待开工 | 另需开工 · 改名后 id 仍稳定 |
| 3 | MCP 烟雾（`lyria_status` / `play` / `pause` / `search`） | 待开工 | 另需开工 · stdio · server name `lyria` |
| 4 | Queue + shuffle/repeat | 待开工 | ended 行为正确 |
| 5 | SwiftUI 各页（艺人/专辑/歌单/设置）+ 空态 | 待开工 | 壳已有；页面树按 UI/IA 补齐 |
| 6 | 空态/错误态 | 待开工 | 按锁定文案 |
| 7 | 可选 HTTP 层 | 待开工 | 可关且 MCP 仍好 |
| 8 | 菜单栏 + 设置打磨 | 待开工 | popover 同步状态 |
| 9 | 真机证明清单 | 待开工 | 见验收 |

### 阶段门闩

1. **阶段 0 门闩** — 静态壳已放行。完整引擎/MCP 另需明确开工；配 CloudAgent 前确认 GitHub remote。无 remote 则只本地 git。
2. **阶段 1 证明** — 命令或 UI 按钮播放指定 path，耳机/扬声器有声；status 时钟前进。
3. **阶段 3 证明** — MCP 客户端调 `lyria_search` → `lyria_play(id)` → `lyria_pause`，与 UI 状态一致。
4. **阶段 7 证明** — 关掉 HTTP 开关后再走一遍 MCP，行为不变。

---

## 验收标准

- [ ] 在 M1 Pro 上成功编译运行 Lyria
- [ ] 播放真实本地音频文件（非静音 fake）
- [ ] MCP `lyria_play` / `lyria_pause` / `lyria_search` 可用
- [ ] 文件重命名后同一指纹仍映射同一 `trk_`
- [ ] HTTP 关闭时 MCP 仍完整工作
- [ ] 空曲库/空歌单/不可播/引擎不可用态符合锁定文案
- [ ] 菜单栏与主窗口传输状态一致

---

## 风险与未决

| 项 | 说明 | 状态 |
| --- | --- | --- |
| GitHub remote | 计划 `Ever12349/lyria`（私有）；创建/推送需用户确认。无 remote 不做 CloudAgent | 未决 / 待创建 |
| 仓库文件夹名 | 磁盘路径已为 `/Users/qianxiao/worker/AIAgent/lyria`（由原 `vinyl` 更名） | 已落地 |
| 多曲库根 | 产品允许「若实现干净」；默认先单根 `~/Music`，多根为增强 | 提议 |
| FLAC | 取决于系统 AVFoundation/解码器可用性；不支持时扫描跳过并计日志，播放给明确格式错误 | 平台限制 |
| App Sandbox | 若上架或开沙盒，必须 security-scoped bookmark；个人自用可先关沙盒降摩擦 | 提议先关 |
| 艺人/专辑 id 命名空间 | 提议对规范化名指纹，与文件内容指纹分离；若用户要改再锁 | 提议 |
| 视觉还原 | 已锁：尽量贴 + AppKit 补刀；非像素完美。不走 Web 壳除非用户改口 | 已锁 |

**约束重申：** 静态壳可继续抠；引擎/MCP/HTTP 另需开工；无 CloudAgent 直到 remote 存在且用户同意；agent 面是 MCP/HTTP，不是截图。设计资产以 `.design/` 为准。

---

*本文档由 Canvas「Lyria 全流程开发文档」导出并按正式路径 `…/AIAgent/lyria` 更新。交互式版本：[Canvas](https://cursor.com/canvas/store-669ca32f-ae0c-4bc0-be04-6e46150cff28/37c89944-4d8d-4256-b8f6-e516d782a9f4)。*
