# Lyria 全流程开发文档

个人本地音乐播放器 **Lyria**（macOS / Apple Silicon）从产品边界、架构、曲目 id、曲库、引擎、窗口壳层、UI、MCP/HTTP 到分阶段验收的完整技术规格。

> **阶段顺序覆盖（2026-11-09 · 曲库切片已开工）**  
> **阶段 2（曲库）先于阶段 1（引擎）。** 本切片做本地导入和曲库管理。引擎 / MCP / HTTP / MenuBarExtra 仍停放，引擎须另说开工。UI 壳已经落地，本切片接在它上面。  
> **相对下文旧句，实现以本段为准：**  
> 1. 删除 `user_hidden`（schema 与 UI 都没有）。「从曲库移除」= **硬删除** `tracks` 行；**保留** `fingerprints`（再导入同一内容复用 `trk_`）；级联删除 `playlist_tracks`；删除 `Artwork/trk_….jpg`；艺人/专辑 `track_count` 归零则删除该行。  
> 2. **启动不自动扫描**，也 **不**把 `~/Music` 写入 `scan_roots`。设置里没有曲库路径、也没有「立即扫描」。只有空曲库的「扫描曲目」会打开文件夹选择器（已有根时预填该目录），写入 bookmark 后做增量扫描。换根不弹确认。  
> 3. 本切片播放控件全部置灰（代码里标 `TODO(engine)`）。传输条显示「—」，没有假 now-playing。保留：加入播放列表、前往艺人/专辑（id 非空）、从曲库移除、设置、播放列表的新建/改名/删除/加歌/移出（**没有**拖拽排序）。  
> 4. `encoding_suspect` **只**认 U+FFFD，不做 Latin-1 占比启发。规范化后艺人或专辑为空则不铸 `art_` / `alb_`，界面显示「未知艺人」「未知专辑」并禁用前往。缺标题用去掉扩展名的文件名。`sort_name = normalize(name)`。年份解析不了就是 0。封面取内嵌图，否则同目录 `folder.jpg` / `Cover.jpg`。扫描并发上限 **4**。进度只出现在曲库页标题下：`正在扫描曲库 · N%`，可「取消」。Toast 只有结束、失败、取消（「已取消扫描」），没有「开始扫描」。清除指纹用 `NSAlert`。  
> 5. 沙盒保持关闭；`scan_roots.bookmark` 从第一天写入。Bundle id 保持 `local.lyria.sample`。系统 SQLite3，不用 GRDB。单根。  
> 6. **多选与批量（2026-11-10）：** 单击替换选中；⌘ 单击切换；⇧ 单击从锚点选区间（锚点＝最近一次非 ⇧ 单击，⇧ 不移动锚点）。Esc 只清选中，不清搜索；不点空白清选中。`selectedTrackIds` 是唯一选中真相。曲库、艺人、专辑、播放列表、搜索的 `TrackTable` 共用。⌘A /「全选」只选当前表；搜索框或改名框聚焦时 ⌘A 留给系统选文字。换页、后退、打开详情、侧栏、搜索词变化都清选中。批量条只在选中 ≥ 2 时以胶囊出现在标题行里（标题与搜索之间），顺序是标题行（含批量胶囊若 N≥2）→ 扫描条（若在扫）→ 页面。窗口最小 980×640。动作：加入播放列表（按当前表从上到下；toast「已加入 N 首到「X」」，有跳过再加「跳过 M 首（已在列表）」，全部已在则「已在「X」中」；成功后保留选中）、播放列表内「从列表移除」、从曲库移除（多首一次确认，其余只 toast）。播放 / 下一首 / 加入队列仍禁用。右键和行内 ⋯：行已在选中里则作用于整组，否则先改成只选该行。`deleteTracks` / `addTracks` / `removeTracksFromPlaylist` 各一次事务、一次刷新；硬删除仍保留指纹并删封面、清零艺人/专辑行。  
> 设计资产仍在 `.design/`。交互式规格见 [Canvas](https://cursor.com/canvas/store-669ca32f-ae0c-4bc0-be04-6e46150cff28/37c89944-4d8d-4256-b8f6-e516d782a9f4)。



## 产品边界

| 项 | 值 |
| --- | --- |
| 产品 | Lyria — 个人本地音乐播放器；仅本机曲库，无云同步、无流媒体账号 |
| 目标机 | Mac · Apple M1 Pro · my-notebook-2.local |
| 仓库路径 | `/Users/qianxiao/worker/AIAgent/lyria`（正式项目目录；品牌与文件夹均为 Lyria / lyria） |
| GitHub remote | 私有仓 [Ever12349/lyria](https://github.com/Ever12349/lyria)；SSH `git@github.com:Ever12349/lyria.git` |
| 技术栈 | macOS-native Swift · SwiftUI + 必要处 AppKit · 音频用 AVFoundation |
| 人机面 | macOS 主窗口（标题 Lyria）+ 菜单栏 MenuBarExtra（不是设计参考里的移动双 Tab 壳） |
| Agent 面 | MCP 为主（server name `lyria`）；Cursor 等客户端经 **stdio 薄桥**附着到已运行的 App 内引擎；本地 HTTP 可选同能力层 |
| 证明完成 | 真机播放真实文件 + 至少一条 agent 调用路径（优先 MCP） |
| 非目标 | 截图操控桌面、跨机分享曲库、云歌词、DRM 商店内容、第三方 FLAC 解码器、MVP 并行维护 XPC/Mach IPC |

**同名品牌说明：** 另有设计参考工程亦名 Lyria，路径 `/Users/qianxiao/worker/reactactive/Lyria`（含 Figma Deep Space）。那是视觉/交互参考应用；本文档描述的是本仓库的 macOS 本地播放器产品，同样品牌名为 Lyria。二者同品牌、不同工程，勿混为同一仓库。

两个表面共用**同一份**引擎状态：人在窗口/菜单栏操作，agent 经 MCP（或可选 HTTP）改同一 `TransportState` / `Queue`。MCP 客户端拉起的是薄桥进程，不另起第二份引擎或曲库。关掉 HTTP 不得影响 MCP。Agent 接口是 MCP/HTTP 工具，不是截图或桌面驱动。

---

## 架构总览

**单实例、单引擎：** 播放与曲库只存在于正在跑的 `Lyria.app` 进程。`LibraryIndex` 管指纹与元数据；`PlaybackEngine` 管 AV 解码与时钟；`Queue` + `TransportState` 是唯一真相源。App 内嵌的 MCP 会话服务与可选 `HTTPServer` 都只调这份引擎，互不代理。

Cursor / Claude 等 MCP 客户端按协议会另起一个 **stdio 子进程**。业内默认做法（Cog、Xcode `mcpbridge`、TRMNLY 等）是：该子进程**不**持有引擎，只做 **stdin/stdout ↔ 本机 IPC** 的薄桥，附着到已开的 App。

```text
Cursor / Claude Desktop          Lyria.app（唯一引擎进程）
        │                                │
        │  stdio JSON-RPC                │  SwiftUI + MenuBarExtra
        ▼                                │
  lyria-mcp / --mcp                      │
  （薄桥 · 无引擎）                       ▼
        │              TransportState + Queue  ← 唯一真相源
        │  Unix domain socket                  │
        │  Application Support/Lyria/mcp.sock  │
        │  (via FileManager API; sandbox-safe) │
        └───────────────► MCP session ─────────┤
                           HTTPServer? ────────┤
                              │                │
                         ┌────┴────┐           │
                         ▼         ▼           │
                   PlaybackEngine  LibraryIndex
                   (AVFoundation)  (扫描·指纹·SQLite)
```

MCP **不**经 HTTP 转发；两者并列挂在同一状态机上。HTTP 关闭后 MCP 仍完整可用。日志与诊断只走 stderr / 文件，**不得**写入 stdout（stdout 仅 JSON-RPC）。

---

## MCP 进程模型（已锁定）

> **已锁定（2026-11-07）** — 采用业内默认的「薄桥 + 单实例附着」，不再采用「每个 MCP 子进程各自一份引擎」或「强制 Agent 只能拉起带窗进程且 stdout 混用」的模型。

### 角色

| 角色 | 是什么 | 职责 |
| --- | --- | --- |
| `Lyria.app` | 唯一产品进程 | 窗口、菜单栏、曲库、`PlaybackEngine`、`TransportState`/`Queue`；内嵌 MCP session（接 IPC，调引擎） |
| `lyria-mcp` 或 `Lyria --mcp` | Cursor 配置里的 command | **哑桥**：把 stdio 上的 JSON-RPC 原样转到 App 的本机端点；不解析业务、不持有状态 |
| MCP 客户端 | Cursor / Claude Desktop 等 | 只认识那条 stdio command，不管 App 内部 |

对标：开源播放器 [Cog](https://github.com/losnoco/Cog) 的 `cog-mcp`（Unix socket 字节泵）；Apple [Xcode `mcpbridge`](https://martiancraft.com/blog/2026/11/xcode-mcp-server-setup-guide/)（stdio ↔ XPC）；[TRMNLY](https://trmnly.dev/docs/mcp) / [Music MCP](https://musicmcp.app/llms.txt) 同类桥接。

### 生命周期

1. **人从 Dock / Finder 打开 `Lyria.app`** → 正常起窗口 + 唯一引擎；在本机发布 MCP 端点。**IPC（已锁）：** 仅 **Unix domain socket**。路径 **不得手写 `~/…` 字符串**，须用 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` 解析出的 Application Support，再拼 `Lyria/mcp.sock`（开沙盒时进容器路径；关沙盒时等价于用户家目录下的同相对路径）。XPC / Mach 为非目标 / 将来可换，**MVP 不并行实现**。
2. **客户端启动 `lyria-mcp`（或同二进制 `--mcp`）** → 探测已有实例；连上后 stdin→socket、socket→stdout；客户端退出时半关闭写端并退出。**桥重试（已锁）：** 若 App 尚未 listen，桥对连接做 **指数退避重试直至可连**（预算约 **≤ 3s**），超时再报明确错误；不得假成功。
3. **没有实例时（已锁 · 阶段 3）** → 桥或 `--mcp` **拉起同一份** `Lyria` 二进制且 **始终带窗**（同一 GUI 进程）；引擎仍只有一份。无头 / `LSUIElement` **延后**，不进阶段 3。之后 Dock 再开应 **只激活已有进程**，不得起第二份引擎。**沙盒注：** 桥与 App 必须看见同一 socket 路径——MVP 用 **同一二进制 / `--mcp`**（或同包内助手）保证；勿把桥做成进不了 App 容器的独立工具。
4. **单实例探测** → 以上述 API 解析的 socket + lockfile / `NSRunningApplication` 等可靠手段；后启动的 GUI 激活前者，后启动的 `--mcp` 只附着。
5. **死 socket（已锁）：** App listen 前：若 `mcp.sock` 已存在且 **无法连上**（崩溃残留）→ **`unlink` 后再 bind**；若已有存活实例在听 → 本进程不得抢绑，走「只激活」路径。

### 硬约束

- App 内 GUI run loop 与 MCP session **同进程**；桥进程无 AV、无 SQLite、无第二份 `TransportState`。
- 验收：`lyria_play` / `lyria_pause` 与**主窗口**看到的状态必须一致——因为改的是同一份状态机。**菜单栏**同步归阶段 8，不进阶段 3 证明。
- stdout 纯 JSON-RPC；调试日志走 stderr。
- MCP **不**默认、也 **不**要求经 HTTP；HTTP 可关且不得拖垮 MCP。
- 设置里可提供「允许经 MCP 远程控制」开关（对标 Cog）；关闭时桥应明确报错（无法连接），不得假成功。

### 客户端配置（示意，开工后写死路径）

```json
{
  "mcpServers": {
    "lyria": {
      "command": "/Applications/Lyria.app/Contents/MacOS/lyria-mcp"
    }
  }
}
```

或指向同包内主二进制加 `"args": ["--mcp"]`。具体 bundle 内路径在阶段 3 落地时写入 README。

### 实现落点（开工后）

| 组件 | 说明 |
| --- | --- |
| `Agent/MCPServer.swift`（或改名 `MCPSession`） | **跑在 App 内**：接本机 IPC，注册 tools，调引擎 |
| `Agent/MCPBridge` / 独立 `lyria-mcp` target | **薄桥可执行文件**：stdio ↔ socket；无业务依赖 |
| 单实例 / 端点发布 | socket 经 Application Support API → `Lyria/mcp.sock`；listen 前 unlink 死 sock；桥 ≤3s 退避；无实例**带窗**拉起；Dock 二次启动只激活 |

阶段 1 写播放器之前，进程模型以本节为准；不要按「stdio 与引擎同进程且每个 MCP 客户端一份引擎」往下长。

---

## 模块与目录

建议 SPM + Xcode macOS App 目标。包名与可执行目标优先 Lyria（CFBundleDisplayName / 窗口标题均为 Lyria）。**MCP session 内嵌在 App 进程**；另提供薄桥入口（独立 `lyria-mcp` target，或主二进制 `--mcp`），供 Cursor 等以 stdio 拉起并附着到已开实例——见 [MCP 进程模型](#mcp-进程模型已锁定)。

壳层源码仍在 `Sources/Lyria/`（外加 `Library/`）。下列为完整产品**目标**结构。**2026-11-09：** `LyriaCore` + `LyriaTests` 已随曲库切片落地，且 **阶段 2 先于阶段 1**。引擎目录仍不创建（Amb-5 的 `Sources/Lyria/Engine/` 留给以后的引擎开工）；壳层暂不迁到 `App/`。

| 路径 | 职责 |
| --- | --- |
| `App/` | LyriaApp、主窗口 Scene、MenuBarExtra（目标树；阶段 1 仍用现有扁平入口） |
| `App/Views/` | Shell、曲库表、艺人/专辑/歌单页、设置、空态组件 |
| `App/Theme/` | Deep Space 色板、圆角、玻璃材质 token |
| `Sources/Lyria/Engine/PlaybackEngine.swift`（阶段 1）/ 目标 `Engine/…` | AV 会话、当前项、seek、音量；**`actor PlaybackEngine`** |
| `Sources/Lyria/Engine/TransportState.swift` | **`@MainActor` + `@Observable`**；playing、positionMs、durationMs、shuffle、repeat、volume |
| `Sources/Lyria/Engine/Queue.swift` | `QueueItem` 类型；阶段 1 仅当前一项；完整 next/previous/插队 = 阶段 4 |
| `Library/LibraryIndex.swift` | 扫描调度、增量策略 |
| `Library/Fingerprint.swift` | SHA-256 / 头尾兜底、Crockford Base32、`trk_` 生成 |
| `Library/MetadataReader.swift` | AVAsset 标签与封面 |
| `Library/Models.swift` | Track / Artist / Album / Playlist 值类型 |
| `Persistence/Database.swift` | **系统 SQLite3** 薄封装：打开、`user_version` 迁移；**不用 GRDB** |
| `Persistence/Schema.sql` | 表定义 |
| `Agent/MCPServer.swift`（或 `MCPSession`） | **App 内** MCP session：本机 IPC → tools → 引擎；name `lyria` |
| `Agent/MCPBridge` / `lyria-mcp` | **薄桥**可执行文件：stdio ↔ `…/Lyria/mcp.sock`；无引擎 |
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
2. **大文件阈值（已锁定）：`size ≥ 32 MiB`** 时用 `hash(头 64KB + 尾 64KB + 文件大小)`，method 记 `head_tail_size`；否则 `full`。**阈值入库后不得事后修改**（改 = 换库 = 清空指纹库）。
3. 持久化 fingerprint → id 映射；同一指纹复用同一 id（去重）。
4. 路径是属性：路径变、指纹不变 → 更新 path，不换 id。
5. 文件缺失：id 保留为 tombstone；队列/歌单显示「文件缺失」；指纹再现 → 复活同一 id。
6. 硬链/拷贝：同指纹多 path → **一条曲目**；保留主 path，其余 **必须** 持久化写入 `tracks.aliases_json`（**已锁 · MVP；删除「可先只打日志」**）。**主 path 缺失但副本仍在 → 自动切主 path 到仍存在的副本**（依赖已持久化的 aliases），再谈 tombstone。无 aliases 持久化则禁止宣称自动切主路径。
7. 仅改标签、内容不变：id 不变，刷新元数据。
8. 清空指纹库 = 换库；设置里单独警告。

### 艺人 / 专辑名规范化（已锁定 · 第一次入库前）

生成 `art_` / `alb_` 之前必须：

1. 标签字符串先做 **Unicode NFC**；
2. trim + 连续空白折叠为单空格；
3. **`encoding_suspect`（已锁 · MVP）** — **必选规则仅一条：** 元数据字符串（`AVMetadataItem` 等给出的已解码 `String`）含 **U+FFFD**（替换字符）→ 记 `encoding_suspect=1`。
   - **不得**把「按 Latin1 解出的原始字节 / 高位字节占比」当作必选路径：AVFoundation 通常只给已解码 `String`，拿不到那串字节；若把 Unicode 码点误当高位字节，正常中文标题会整批变可疑。
   - **本切片不做可选启发**（只认 U+FFFD）。下文这条若以后要做，必须写死码点，否则不要做： 在 **已是 Unicode 字符串** 上统计码点落在 `U+0080–U+00FF` 的占比 **≥ 30%**，**且** 串内 **不含** 下列任一范围 → 亦可标 suspect：CJK Unified Ideographs `U+4E00–U+9FFF`、Hiragana `U+3040–U+309F`、Katakana `U+30A0–U+30FF`、Hangul Syllables `U+AC00–U+D7AF`。全角标点等未列入「挡板」范围；有上述任一脚本码点则 **不得** 仅因 Latin-1 区占比而标 suspect。
   - **suspect 后果（已锁）：** `artist_id` / `album_id` = **NULL**；**不得**铸造 `art_` / `alb_`；**不得**发明 `suspect:<track_id>` 一类伪艺人/专辑 id（艺人表与「前往艺人 / 前往专辑」无落点）。UI/MCP：**禁用**「前往艺人」「前往专辑」；曲目仍可显示原文 title/artist/album 字符串。
   - **不做**完整 GBK / 多编码分类器。开工时附 fixture（至少：含 U+FFFD → suspect；正常中文 → 非 suspect）；规则与向量进仓库；**事后改规范化 = 换库。**
4. **艺人 id：** 对规范化后的艺人名做 SHA-256 前 16 字节 → Crockford → `art_`。
5. **专辑 id（已锁 · 输入）：** 哈希输入 = `normalize(artist) + "\0" + normalize(album)`（等价允许：`art_id + "\0" + normalize(album)`，在已有 `art_` 时）。**禁止**只哈希专辑名。测试向量要求：同名专辑、不同艺人 → **不同** `alb_`（例：「Greatest Hits」）。艺人或专辑侧为 suspect / 空 → 不铸 `alb_`（`album_id` NULL）。

### 禁止

- 路径字符串当 id
- inode 当长期 id
- 对外暴露自增数字 id

### API 约定

曲库列表与按 id 播放仍只认 `trk_…`。**队列项（已锁定）** 为 tagged union，阶段 1 起就用，禁止先「只按 path」再在阶段 3 改 API：

```swift
enum QueueItem {
  case track(Track.ID)   // trk_…
  case oneShot(URL)      // file:// 一次性；不入库、不分配 trk_
}
```

`POST /play` / MCP `lyria_play` / 队列插入同一套：`id?` **XOR** `uri?` — `id` → `.track`；`uri: file://…` → `.oneShot`；二者同时有 = 参数错误；二者都空（仅 play）= resume。曲目对象固定字段：`id` · `path`/`uri` · `title` · `artist` · `album` · `durationMs` · `missing?`（可选 bool）。**oneShot 对外状态（已锁）：** 不分配 `trk_`；`lyria_status` / `GET /status` 的 `track.id` = **`null`**，**必须**带可播放的 `uri`（`file://…`）；其余展示字段仍可从文件标签填充。假数据与设计稿也只使用 `title` / `artist` / `album`，**禁止**「中文标题 + 英文次行」这类 schema 外结构。

### Crockford Base32 实现要点

字母表：`0123456789ABCDEFGHJKMNPQRSTVWXYZ`（排除 I L O U）。编码 16 字节 → 26 个 5-bit 组需补零到 130 bit，取前 22 个字符（固定输出长度 22）。解码时大小写不敏感；遇到 `I→1`、`L→1`、`O→0`、`U` 拒绝。

**已知测试向量（已锁）：** 16 字节全零 → 22 个 Crockford `0` → 曲目 id 字符串为：

```text
trk_0000000000000000000000
```

（`trk_` + 22 个 `0`。）单元测试必须锁此向量，防止实现漂移。

**测试与双工程（已锁方向）：** `Package.swift` 增加 `LyriaCore`（指纹/模型等可测库）+ `LyriaTests`；`Lyria.xcodeproj` 与 Package **必须同步**加测试 target / 日后 `lyria-mcp`，禁止只改一边。仓库目前尚无测试 target——开工阶段 2 前补上。

---

## 曲库扫描

| 项 | 值 |
| --- | --- |
| 默认根目录（**2026-11-09 覆盖**） | **单根，不预置路径**。首次启动不写 `scan_roots`，设置显示「未选择」，直到用户选定一个文件夹。**启动不自动扫描**。多根仍延后 |
| 格式 | AVFoundation 能播的：mp3、m4a/aac、aiff、wav；flac 视系统可用性——不能播则跳过并明确错误（见风险）；**非目标：接入第三方 FLAC 解码器** |
| 元数据 | 优先 AVAsset / AVMetadataItem；封面嵌在文件或同目录 `folder.jpg` / `Cover.jpg` |
| 增量（**已锁**） | path + size + mtime 快路径；未变则跳过指纹；变更或新文件再算指纹校验 |
| 大文件阈值 | **已锁：≥ 32 MiB → `head_tail_size`**；写入 `fingerprints.method`；不得事后改 |
| 全量 | 扫描器仍保留 `force` 参数（强制重指纹、不无故换 id）。**当前 UI 不提供重扫**，空曲库入口始终 `force: false` |

### 扫描步骤

1. **枚举** — 对每个库根递归；跳过隐藏与已知非音频扩展名；尊重书签/安全作用域（若开沙盒则保存 security-scoped bookmark）。
2. **快路径** — path 已在库且 size+mtime 未变 → 跳过指纹。否则进入指纹。本切片没有 `user_hidden`。
3. **指纹与 upsert** — 算指纹；查 map；命中则更新 path/元数据/`aliases_json` 并复用已有 `trk_`（用户删过曲目行也一样，只要指纹还在）；未命中则分配新 `trk_` 并写 map。
4. **tombstone** — 本轮「未见」的 path：标记 `missing`；不删 id；播放时拒绝并表面错误。**例外见下条 iCloud。**
5. **艺人/专辑聚合** — 按上文**已锁定**的规范化与哈希输入生成或复用 `art_` / `alb_`（专辑 = 艺人+专辑名；与曲目指纹独立命名空间）。
6. **iCloud 占位（已锁 · 与 tombstone）** —
   - **尚未入库**的 ubiquitous / 未本地下载占位 → **跳过**并记原因（如 `icloud_placeholder`）；不触发整库下载，不算失败指纹。
   - **已在库**且本轮发现该 path 变为 iCloud 占位 → 计为本轮 **「见过」**，**不得**因此置 `missing`；可选列/标志 `icloud_offline=1`（UI 可提示「需下载」）。**真删除**（路径不存在且非占位）才 tombstone → `missing`。
7. **并发** — 指纹与 `AVAsset` 读标签在后台 `Task`，同时最多 **4** 个文件；**不得堵主线程**。本切片还没有播放引擎。

进度只挂在曲库页、搜索未打开、且扫描进行中：标题下方一条 `正在扫描曲库 · N%`，旁边「取消」。不显示当前文件名。取消只停止继续调度，已入库的行保留，并用本轮已经看到的文件做 `finishScan`，然后 toast「已取消扫描」。扫描过程中大约每 0.5 秒刷新一次曲库列表，结束时再刷新一次。Toast 只有完成（`扫描完成 · N 首`，有跳过时带上跳过数）、失败、取消，不报「开始扫描」。同指纹多路径：主 path + **持久化** `aliases_json`；主 path 没了自动切副本（见 id 节）。没有 `user_hidden`，列表不过滤隐藏行。

---

## 持久化 schema

根目录：经 `FileManager` Application Support API 解析的 `…/Lyria/`（同目录放 MCP socket `mcp.sock`；开沙盒时为容器内路径）。主库 `library.sqlite`；封面缓存 `Artwork/trk_….jpg`（或按 hash 分片）。设置也落在同一 SQLite 的 `settings` 表，避免散落 plist 双源。

**SQLite 选型（已锁）：** 使用 **系统 SQLite3** + 薄封装 `Persistence/Database.swift`（`user_version` 整数迁移）。**不上 GRDB** 或其它 ORM。

| 表 | 列（要点） |
| --- | --- |
| `fingerprints` | `fingerprint TEXT PRIMARY KEY` · `track_id TEXT NOT NULL UNIQUE` · `method TEXT (full\|head_tail_size)` · `created_at` |
| `tracks` | `id TEXT PK` · `path`（主路径）· `aliases_json`（**TEXT，MVP 必写**；同指纹其它 path 的 JSON 数组）· `title` · `artist_name` · `album_name` · `artist_id` · `album_id` · `duration_ms` · `size` · `mtime` · `missing INTEGER` · `encoding_suspect INTEGER` · `icloud_offline INTEGER`（可选，默认 0）· `updated_at` |
| `artists` | `id TEXT PK` · `name` · `sort_name` · `track_count` |
| `albums` | `id TEXT PK` · `name` · `artist_id` · `year` · `track_count` · `artwork_path` |
| `playlists` | `id TEXT PK` · `name` · `created_at` · `updated_at` |
| `playlist_tracks` | `playlist_id` · `track_id` · `position INTEGER` · `PK(playlist_id, position)` |
| `settings` | `key TEXT PK` · `value TEXT`（JSON 或标量字符串） |
| `scan_roots` | `id INTEGER PK` · `path TEXT UNIQUE` · `bookmark BLOB` · `enabled` |

迁移用整数 `user_version`；v1 即上表。清空指纹库 = `DELETE fingerprints` + 相关 tracks 并警告；歌单里的 id 会变 orphan，UI 标缺失。WAL 模式。**连接模型（已锁定方向）：** 单一 writer actor 串行写；读可用只读连接或同 actor 查询，避免多写者竞态。歌单重排、tombstone、复活放在同一事务。备份：用户可复制整个 `Application Support/Lyria` 目录。`scan_roots.bookmark` **从第一天就写**（**已锁 · C2：** MVP 关沙盒，仍写 bookmark），避免日后开沙盒时路径全废。

---

## 播放引擎

> **推荐选型** — 使用 `AVPlayer` + `AVPlayerItem`（非 `AVAudioPlayer`）。理由：统一 seek/状态 KVO、支持更多容器；音量用 `AVPlayer.volume`；仅在未来加 EQ 时再上 `AVAudioEngine`。**无缝换曲不进验收**（`replaceCurrentItem` 对 mp3 常有间隙，属平台常态）。

| 项 | 值 |
| --- | --- |
| 会话 | playback 类别；macOS 用默认输出设备 |
| 时钟 | `addPeriodicTimeObserver` 约 2–4 Hz 推 `positionMs` 到 TransportState |
| 换曲 | `replaceCurrentItem`；ended → 见下方状态机 |
| 队列项 | **已锁：** `QueueItem = track(trk_)` 或 `oneShot(file://)`，见 id「API 约定」 |
| shuffle | 打乱索引、保留原序；**插入下一首 / 删项 / 清空时显式重建索引**，禁止沿用失效索引 |
| repeat | `off` \| `all` \| `one`；ended 处理里 **先看 mode 再互斥分支**（`one` → `seek(0)`+play；否则进下一首），禁止双路径竞态 |
| 缺失/不可播 | 不假装成功；抛错给 UI toast + MCP/HTTP error body |
| 成功语义 | `play` 等 `AVPlayerItem.status == .readyToPlay`（或明确失败）再回 ok；**禁止**把「已开始加载」报成成功 |

### 多写入者（已锁定）

UI 拖进度、菜单栏、MCP、HTTP、时间观察、ended 通知都会改队列/进度。**唯一写入者：** `actor PlaybackEngine` 串行消费命令；各方只 `enqueue`（play/pause/seek/queueMutation/…），禁止直接改 `Queue` / `TransportState` 可变字段。**线程（已锁 Amb-10）：** `actor PlaybackEngine` → 推送到 `@MainActor TransportState`（UI 只读状态）。

**TransportState（已锁 Amb-2 / Amb-4 / Amb-18）：** `@Observable`（macOS 14+；**不用** `ObservableObject`）。字段：`current: NowPlaying?` · `playing` · `positionMs` · `durationMs` · `shuffle` · `repeatMode` · `volume` · `queueCount` · `engineAvailable` · `lastError?`。状态**只存毫秒**；View 把 `positionMs/durationMs` 派生为 0…1 再驱动滑条 / seek。所有表面只绑这份状态。

**`NowPlaying`（与 status JSON 同形 · Amb-2）：**

```swift
struct NowPlaying {
  var id: String?          // 库内 trk_…；oneShot = null
  var uri: URL?            // oneShot 必填 file://；库内可填 path 对应 uri
  var title: String
  var artist: String
  var album: String
  var durationMs: Int
  var missing: Bool
}
```

队列仍用已锁 `QueueItem`（`.track` / `.oneShot`），与 `NowPlaying` 分离。

### 阶段 1 试播入口（已锁 · C1）

**主入口（已锁 Amb-14）：** 菜单 `commands`「试播…」（可选日后再加传输条旁按钮；**勿**放标题行穿透带）。→ `NSOpenPanel` 选**一个**本地音频文件 → 铸 `QueueItem.oneShot(fileURL)` → `PlaybackEngine.play(uri: file://…)`（与日后 MCP/HTTP 的 `uri` 同形）。

| 项 | 值 |
| --- | --- |
| 入库 | **不**写入 SQLite / **不**分配 `trk_` |
| API | **禁止**另开 path-only / String path 并行播放 API；一律 `file://` URL → `.oneShot` |
| OpenPanel 类型（Amb-16） | 对齐 MVP：`mp3` / `m4a` / `aac` / `aiff` / `wav` 对应 UTType；**不**开 `public.audio` 全格式 |
| 展示文案（Amb-15） | 轻量 `AVAsset` 读标签；失败则用文件名；**不做**完整 `MetadataReader` |
| 成功 | 等 `AVPlayerItem.status == .readyToPlay`（或明确失败）再报 ok |
| 失败 UI（Amb-8） | `NSAlert` 或临时横幅 + `TransportState.lastError`；完整 toast / 空态文案 = **阶段 6** |
| 验收句 | 与「阶段门闩 · 阶段 1」一致：OpenPanel 选文件后本机人工听有声；`TransportState` 时钟前进 |

### 阶段 1 已锁决策（Amb-1…19 · 用户确认「全部按照建议」）

- **Amb-1 初始音量：** 启动 / 新会话 `volume = 1.0`（跟 `AVPlayer` 默认）；静音恢复仍 **0.6**；编码时删壳里写死的 `0.72`。
- **Amb-2 `current`：** `NowPlaying` 结构体（上表）；镜像 status JSON；Queue 仍用 `QueueItem`。
- **Amb-3 错误码（阶段 1 起写齐）：** `unsupported_format` · `missing_file` · `bad_request` · `not_ready` · `failed` · `not_found`。
- **Amb-4 观察层：** `@Observable`（macOS 14+）。
- **Amb-5 目录：** 引擎进 `Sources/Lyria/Engine/`；暂不整树迁 `App/`。
- **Amb-6 真相源：** 传输条绑 `TransportState`；曲库列表**可暂留** `FakeData`；**禁止**传输假状态与引擎双真相。
- **Amb-7 进度时钟：** 重申规格——`addPeriodicTimeObserver` 约 **2–4 Hz**；不另开 Timer 当真源。
- **Amb-8 试播失败：** 见上表（临时 Alert/横幅 + `lastError`）。
- **Amb-9 Queue 深度：** 阶段 1 **仅当前一项**；prev/next **no-op 或置灰**；`QueueItem` 类型从阶段 1 起存在；完整队列 = 阶段 4。
- **Amb-10 线程：** `actor PlaybackEngine` → `@MainActor TransportState`。
- **Amb-11 FakeData `subtitle`：** 阶段 1 **顺手删除**字段与次行（禁双标题）。
- **Amb-12 LyriaCore：** 阶段 1 不建引擎侧 Core；**曲库切片（现先于引擎）已建** `LyriaCore` + `LyriaTests`，并与 `Lyria.xcodeproj` 同步。
- **Amb-13 bundle id：** 保持 `local.lyria.sample`；改名锁在阶段 8 + `SMAppService`。
- **Amb-14 试播控件：** 以菜单 `commands` 为主。
- **Amb-15 oneShot 文案：** 轻量 AVAsset 标签，回退文件名。
- **Amb-16 OpenPanel UTType：** 对齐 MVP 五格式。
- **Amb-17 播完：** `ended` → **pause**，停在末尾（阶段 1 **无** auto-repeat；repeat 状态机完整行为 = 阶段 4）。
- **Amb-18 进度单位：** 状态只存 `positionMs`/`durationMs`；View 派生 0…1。
- **Amb-19 启动态（接引擎后）：** `playing=false`、`current=nil`；列表可留 FakeData，但**不**标假 nowPlaying 高亮。**例外：** UI 对齐阶段按 Amb-UI-12 **暂留**假 now-playing；接引擎时再切 idle。
- **Amb-20：** MCP 远程开关与桥形态仍延后。曲库切片锁了 `sort_name = normalize(name)`、空艺人/专辑显示「未知艺人」「未知专辑」且不铸 id、`encoding_suspect` 仅 U+FFFD（含中文非 suspect 的测试）。

> **Standing hold：** 引擎代码尚未写。**UI 对齐**与**引擎/MCP**分开门闩：改 UI Swift 须对 UI 说「开工」；真播放 / MCP 须另说开工。未授权前不改 Swift / `pbxproj` / `Package.swift`。
---

## 窗口与壳层逻辑

> **已锁定** — 产品壳是 macOS 原生窗口，不是 Electron，也不是 Grok Bot 自定义 chrome。行为对齐系统「音乐」的标题栏与分栏，不是逐行复刻「音乐」源码。仓库内短文：[`.design/docs/window-chrome.md`](../.design/docs/window-chrome.md)。

| 项 | 值 |
| --- | --- |
| 窗口类型 | `NSWindow` · `styleMask = titled \| closable \| miniaturizable \| resizable \| fullSizeContentView` |
| 标题栏 | `titlebarAppearsTransparent = true` · `titleVisibility = .hidden` · `titlebarSeparatorStyle = .none` |
| 红绿灯 | 系统按钮；视觉上落在左侧栏顶部内部 |
| 拖动 / 双击 | 原生 `NSThemeFrame`：拖动与双击放大/还原由系统处理；禁止自定义 `NSEvent` 监视器，禁止自调 `performZoom` |
| SwiftUI 补丁 | `TitlebarPassthroughContentView`：穿透区收窄为**系统标题栏拖动带**（勿整窗顶 52pt 一律 `nil`）；搜索等控件放在穿透带**下方**或侧栏可点区 |
| 侧栏 | 导航列（曲库 / 艺人 / 专辑 / 播放列表，底部为设置）相对窗口四边留出约 12px，圆角约 18px，自带描边。设置下方不放拖宽示意点 |
| 侧栏宽度 | 可拖 168–320，理想约 228。拖宽用侧栏与详情之间的把手，不在设置下画点 |
| 分栏 | 详情列 = 导航标题 + 搜索 + 页面内容 + 底栏传输。标题、搜索、内容、传输条左右对齐；传输条不伸进侧栏下方 |
| 色板 | Deep Space：bg `#0a0b1a` · accent `#9b87f5 → #7c3aed`；左右同一 Deep Space 底色；禁用 behindWindow vibrancy（会吸桌面壁纸色调） |
| 曲目列表 | 跟导航标题同一列宽。行与行之间一条淡分割线；正在播放的行用强调色。封面占位按专辑区分，同一专辑同色 |

**实现备注：** 当前静态样例用 `HStack` + `SidebarResizeHandle` 替代 `NavigationSplitView`，以实现「红绿灯落在侧栏内」与侧栏拖宽；文档锁定的是行为与布局，具体控件可演进。队列不是永久第三列，而是详情区内可选浮层/面板。

### 标题栏穿透与交互回归（已锁定策略）

- 浮层 / sheet / 右键菜单优先走系统 `NSPanel` / SwiftUI `sheet` / `popover` / `contextMenu`（独立窗口层级），**不要**塞进主窗被穿透的 `contentView` 顶带。
- `WindowChromeConfigurer` 轮询重包 `contentView` 仅作兜底：**仅在 contentView 身份变化时重包**，避免无意义每 3 秒重包。
- **每加一块顶栏/侧栏顶交互**（搜索、设置 sheet、队列浮层、歌单拖拽等）必须在真机回归：窗口拖动、双击缩放、红绿灯、侧栏顶部点击。预算写入阶段计划，不视为一次性配好。

---

## UI / IA

壳层对齐「窗口与壳层逻辑」：左导航是内缩圆角列；右详情列顶部是导航标题，与搜索同一行，并与下面的内容和底栏传输条左右对齐。导航项：曲库 · 艺人 · 专辑 · 播放列表 · 设置。列表页的导航标题就是当前分区，曲库可在标题下标出曲目数量。进入艺人、专辑、播放列表详情，或进入搜索时，标题左侧出现后退图标，与标题文字垂直对齐；点它回到上一页。队列为详情区内可选浮层/面板，不是常驻第三列。窗口标题与菜单栏品牌文案为 Lyria。图标在 SwiftUI 里用 SF Symbols（`Image(systemName:)`），和侧栏同一套线型，颜色跟随文字，不用 emoji。后退用 `chevron.left`。HTML 预览里的 Lucide 只对齐语义（播放、暂停、上一首、后退、更多等），不作为 App 的运行时资源。每个控件怎么操作、有什么限制，见「控件操作与限制」。

| 页面 | 内容 |
| --- | --- |
| 曲库 | 曲目在详情列内滚动，底栏不动。行见「曲目行」 |
| 艺人 | 网格 → 详情：专辑横滑 + 热门曲目 |
| 专辑 | 网格 → 详情：播放全部 / 随机 / 加入队列 + 曲目列表 |
| 播放列表 | 网格 + 新建 → 详情：播放全部 / 随机 / 编辑 / 删除 + 可拖拽曲目 |
| 设置 | 见「设置」节 |
| 空态 / 错误态 | 空曲库、空歌单、搜索无结果、不可播、引擎不可用、文件缺失 — 见「空态与错误态」 |

### UI 已锁决策（Amb-UI-1…16 · 用户确认「全部按照建议」）

> **文档 only · 未写 Swift。** 主窗 UI 对齐 HTML 原型前须另说「开工」；引擎 / MCP 仍停放，另需各自开工。

| # | 决策 |
| --- | --- |
| Amb-UI-1 范围 | **B**：主窗全部分区假数据可点（曲库 / 艺人 / 专辑 / 播放列表 / 设置 / 空态 / 队列）；**不做**真 `MenuBarExtra`（菜单栏 = 阶段 8） |
| Amb-UI-2 空曲库文案 | 「还没有音乐」+ CTA「扫描曲目」/「打开设置」（2026-11-10：原「选择文件夹」改为扫描入口） |
| Amb-UI-3 空歌单文案 | 跟 Spec：「播放列表是空的」+ CTA「添加歌曲」 |
| Amb-UI-4 FakeData | 换成 Dreamscape / 银河边缘 / 星际旅行 等原型集；**删除** `subtitle` 与双标题次行 |
| Amb-UI-5 队列 | **现在**做假队列浮层/面板（可开关） |
| Amb-UI-6 传输条 | **现在**按原型重建三栏布局 |
| Amb-UI-7 封面 + 更多 | 封面按钮与更多菜单**可点**，动作为假（不接引擎） |
| Amb-UI-8 侧栏 | **现在**做约 12px 内缩 + 圆角卡 |
| Amb-UI-9 page-head | **完整**导航标题（曲目数等）+ 可后退 |
| Amb-UI-10 设置 | 六行 **disabled stub**（含路径 / 重扫 / HTTP / 登录项 / 外观 / 清指纹） |
| Amb-UI-11 Repeat | **三态** UI（off\|all\|one）；引擎侧暂 no-op |
| Amb-UI-12 启动态 | **UI 阶段**保留假 now-playing 便于对照原型；接引擎后再按 Amb-19 → `playing=false` / `current=nil` |
| Amb-UI-13 搜索 | 按 proto/规格：假过滤 + `returnTo` 后退语义 |
| Amb-UI-14 Toast | 轻量 pill toast（UI 阶段即可） |
| Amb-UI-15 HTTP stub | 设置 stub **显示关**（跟规格默认关；不以 proto 显示开为准） |
| Amb-UI-16 图标 | **仅** SF Symbols；不用自定义 SVG / emoji / Lucide 资源 |

### 曲目行

正式界面用 SwiftUI。侧栏是 `SidebarView`：相对窗口四边内缩约 12px、圆角约 18px，设置下不放拖宽示意点。曲目行是 `TrackRow`（现写在 `LibraryView` 里）。曲库、艺人热门曲目、专辑详情、播放列表详情共用这一行，不按页面各画一套。

从左到右：封面 · **标题** · **艺人** · **专辑** · 时长 · 更多（字段仅 `title` / `artist` / `album`，与 schema 一致；**禁止**假数据「中文标题 + 英文次行」绑架实现）。行与行之间一条淡分割线。正在播放的行用强调色；只选中、未在播的行用更淡的底。`.design/ui-mocks/html/index.html` 只是同一套行为的可点击预览，验收以 SwiftUI 窗口为准；静态页 01–12 与此同一版式。

| 项 | 行为 |
| --- | --- |
| 封面 | 约 36px、圆角约 8px。尚无真实封面时按专辑给不同渐变，同一专辑同色；封面是**独立 `Button`**，不与行单击抢手势 |
| 均衡器 | 只出现在当前曲目的封面上。正在播放时动，暂停时停 |
| 悬停封面 | 均衡器或封面换成功能按钮：正在播放为暂停，其余为播放 |
| 点封面 | 当前曲目则播放/暂停切换；其他曲目从头播放 |
| 点行 | 只选中，不播放（行容器不兼播放） |
| 双击行 | 播放 |
| 更多 / 右键 | **同一份** `Menu` 内容；`contextMenu` 挂在行上 |

### 手势与拖拽（已锁定策略）

- 行容器：选中；双击：播放；封面：独立按钮；菜单：右键与「更多」共用一份定义，避免 SwiftUI hover / 单击 / 双击 / `contextMenu` 互抢时行为分裂。多选规则以文首第 6 条为准（`TrackSelection` + `BatchActionBar`）。
- 播放列表拖拽排序：提交时 **一次事务** 重写该歌单全部 `playlist_tracks.position`（0..n−1），禁止逐行改 position。

更多菜单：播放 · 下一首播放 · 加入队列 · 加入播放列表（展开现有歌单）· 前往艺人 · 前往专辑（**`encoding_suspect=1`、艺人/专辑为空，或 `artist_id`/`album_id` 为 NULL 时禁用后两项**；空名显示「未知艺人」「未知专辑」）。播放列表详情里再加「从播放列表移除」。曲库及相关列表里是「从曲库移除」：先确认，**硬删除** `tracks` 行，**不删磁盘文件**；**保留** `fingerprints`；级联删 `playlist_tracks`；删封面缓存；艺人/专辑没有剩余曲目则删该行。本切片播放 / 下一首 / 加入队列置灰。

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

> **视觉真源（壳层对齐用 · 已锁文档约定）：** 在另行声明之前，HTML 交互原型 [`.design/ui-mocks/html/`](../.design/ui-mocks/html/)（`index.html` + `theme.css` + `prototype.css` + `prototype.js`，及同目录 01–14 静态快照）是**主窗口壳层的视觉与结构真源**；Swift 壳须跟踪其版式（侧栏内缩卡、page-head、曲目行分割线、三栏传输条、队列浮层等）。PNG/Figma 为辅助对照。**不承诺**与 HTML/Figma 像素级一致（系统红绿灯、字体平滑、毛玻璃必然有差）；验收看结构与 token 是否贴近，差一大截改布局，不硬撑。

---

## 控件操作与限制

正式界面是 SwiftUI 窗口。下面是每个控件的操作和限制，主窗口、菜单栏、MCP、HTTP 写的是同一份 `TransportState` / `Queue`。`.design/ui-mocks/html/index.html` 是可点击预览，不播放音频；预览里多出来的做法见节末，实现时不要照搬。

无当前曲时，传输条封面与标题显示「—」，播放、暂停、上一首、下一首、拖进度都不起作用。空曲库正显示在曲库页、且没有搜索词时，视为无当前曲，并暂停；离开该画面后恢复离开前的播放/暂停。

### 窗口与导航

| 控件 | 操作 | 限制 |
| --- | --- | --- |
| 红绿灯 | 系统关闭 / 最小化 / 缩放 | 不自绘，不自调 `performZoom` |
| 标题栏拖动、双击缩放 | 系统标题栏 | 搜索和导航标题放在穿透带下方，避免抢走拖动 |
| 侧栏拖宽 | 拖侧栏与详情之间的把手 | 宽度 168–320，默认约 228。设置下方没有拖宽圆点 |
| 侧栏「曲库 / 艺人 / 专辑 / 播放列表 / 设置」、品牌 Lyria | 切到该分区的列表 | 清掉搜索、详情和正在进行的重命名。品牌 Lyria 进入曲库 |
| 导航标题 | 列表页显示分区名。曲库在标题下显示当前可见曲目数 | 搜索时标题改为「搜索」，并显示结果数或「无结果」。详情页标题仍是所在分区（艺人 / 专辑 / 播放列表），名称在内容区 |
| 后退 | 在标题左侧。搜索时清除搜索并回到搜索前的页面（含详情）；否则回到上一页 | 只在详情或搜索时出现，并与标题文字垂直对齐。列表根页没有后退 |
| 搜索框 | 输入即搜；点清除或把文字删空，回到搜索前的页面 | 只搜曲库曲目的 `title` / `artist` / `album`，子串、不区分大小写。不搜播放列表名。已从曲库隐藏的曲目不出现。搜索时不显示原来的详情。侧栏切换会丢掉这次搜索，而不是回到搜索前的页 |
| Esc | 按顺序关掉：更多菜单、重命名（取消并恢复原名）、曲库路径菜单、队列、搜索 | 焦点在输入框里时，只处理重命名的 Enter / Esc，不触发播放快捷键 |

### 曲目行

曲库、艺人热门曲目、专辑详情、播放列表详情共用一行。点按钮时，不把这一下同时算成「点行」或「双击播放」。

| 控件 | 操作 | 限制 |
| --- | --- | --- |
| 点行 | 只选中 | 不开始播放。正在播放的行用强调色，不再叠一层选中样式 |
| 双击行 | 从头播放该曲，并选中 | 双击落在封面、艺人、专辑、更多上时，只执行那个按钮 |
| 封面 | 当前曲：播放/暂停切换。其他曲：从头播放，若不在队列则加到队尾 | 独立按钮。悬停时封面或均衡器换成播放/暂停图标。无图时按专辑着色，同一专辑同色 |
| 均衡器 | 只画在当前曲的封面上 | 播放时动，暂停时停。空曲库的「无当前曲」状态不画 |
| 艺人、专辑 | 打开对应详情 | `encoding_suspect=1`，或 `artist_id` / `album_id` 为空：按钮不可用。不凭可疑字节猜一个艺人或专辑 |
| 更多 | 打开与右键相同的菜单。再点同一首的更多则关上 | 同时只开一个菜单。点菜单外或按 Esc 关闭 |
| 右键行 | 在指针处打开同一份菜单 | 不另做一套命令 |

更多菜单，自上而下：

| 项 | 操作 | 限制 |
| --- | --- | --- |
| 播放 | 与点封面相同 | 无当前曲的空曲库画面里不起作用 |
| 下一首播放 | 插到当前曲的下一首 | 队列里已有的同一首先去掉再插入，不留两份。当前曲不在队列时，插到队首。空曲库画面里不起作用 |
| 加入队列 | 加到队尾，并打开队列 | 已在队列中的不重复加。全部已在队列时提示「已在队列中」，不改顺序 |
| 加入播放列表 | 展开现有播放列表，选一个加入 | 只列出已有列表，不在这里新建。已在该列表中则提示，不追加第二份。不改磁盘文件 |
| 前往艺人 / 前往专辑 | 打开详情 | 与行内艺人、专辑按钮同一限制：可疑编码或 id 为空时禁用 |
| 从播放列表移除 | 从当前播放列表去掉这一首 | 只出现在播放列表详情。不二次确认。不隐藏曲库，不删文件 |
| 从曲库移除 | 先确认，确认文案写明文件仍留在磁盘 | 确认后 **DELETE** `tracks` 行。指纹保留，所以再导入得到同一个 `trk_`。`playlist_tracks` 跟着删。封面文件删掉。艺人/专辑计数归零则删行。取消则只关菜单 |

### 列表与详情

| 控件 | 操作 | 限制 |
| --- | --- | --- |
| 艺人卡片、专辑卡片、播放列表卡片 | 打开详情 | 计数只统计未隐藏的曲目 |
| 全部播放 | 用这些曲目替换队列，从第一首开头播放 | 没有可播曲目时提示「没有可播放的曲目」，队列不变。文件缺失或格式不可播的项跳过并报错，不假装成功 |
| 随机 | 用打乱后的顺序替换队列，从第一首播放，并打开随机 | 空列表与「全部播放」同样拒绝 |
| 加入队列（专辑详情） | 把专辑中尚未在队列的曲目加到队尾，并打开队列 | 已在队列的不重复。艺人详情没有这个按钮 |
| 新建播放列表 | 建一个空列表并打开它 | 默认名「新播放列表」；重名则加序号。不自动进入改名 |
| 编辑 | 标题变成输入框并聚焦 | Enter 或焦点离开时提交。空白恢复原名。Esc 取消并恢复原名。只改列表名，不改曲目 |
| 删除 | 先确认，然后回到播放列表网格 | 只删这个列表，不删曲目、不删文件 |
| 添加曲目 | 从曲库选择曲目加入当前列表 | 不提供「把整个曲库一次性倒进来」。已在列表中的不重复 |
| 拖拽排序 | 松手后一次写完该列表全部 `position`（0..n−1） | 不逐行改 position。只在播放列表详情 |

### 传输条与队列

传输条只在详情列底部，不伸到侧栏下面。菜单栏弹出层使用同一组命令。

| 控件 | 操作 | 限制 |
| --- | --- | --- |
| 播放 / 暂停 | 切换当前曲 | 无当前曲时不起作用。空格键相同，但焦点在输入框里时不触发 |
| 上一首 | 进度超过 2 秒：回到当前曲开头。否则切到队列里的上一首，并从开头播放 | 已经是第一首时，只有「重复全部」或随机开着才回到最后一首。无当前曲时不起作用 |
| 下一首 | 切到队列下一首，并从开头播放 | 用户点的下一首在队尾时回到第一首。自然播完时：单曲循环先回到开头继续播，不看「下一首」；重复全部才进下一首并在队尾绕回；重复关闭则停在结尾并暂停。随机开着时，下一首从其余队列项里抽，不连播同一首（队列只剩一首除外）。插入、删除、清空队列后重建随机索引，不用过期下标 |
| 随机 | 开 / 关 | 关掉后恢复原来的队列顺序。重复设置成同一状态不算错误 |
| 重复 | 关闭 → 全部 → 单曲 → 关闭 | 图标：关闭为普通循环，单曲为带 1 的循环。重复设置成同一模式不算错误 |
| 进度条 | 拖到曲目内的位置 | 限制在 0 和时长之间。无当前曲时拖不动。左右方向键各跳 5 秒，同样夹在曲目内；焦点在输入框里时不触发 |
| 音量 | 拖动为 0–1。点喇叭：有声则记住当前音量并静音，已静音则恢复 | **初始音量 1.0**（已锁 Amb-1）；从未有过非零音量时，静音恢复到 **0.6**；编码时去掉壳硬编码 0.72 |
| 队列按钮 | 打开或关上右侧队列浮层 | 浮层不是第三列，不压住侧栏。Esc 可关。队列按钮在浮层打开时为按下态 |
| 队列中的一首 | 从头播放 | 缺失文件拒绝播放并标出「文件缺失」，不从队列里悄悄删掉 |
| 菜单栏弹出层 | 封面、进度、播放/暂停、上一首、下一首，以及接下来最多 3 首 | 与主窗口同一状态。点接下来的一首等于从头播放。阶段 3 不要求菜单栏已与 MCP 对齐，那是阶段 8 |

### 设置

| 控件 | 操作 | 限制 |
| --- | --- | --- |
| 曲库路径 / 重新扫描 | **设置里没有这两行** | 扫描入口只在空曲库：「扫描曲目」→ 文件夹选择器（目录、单选；已有根则预填）→ 写 bookmark → 增量扫描。曲库非空时没有换目录或重扫控件。单根，不预置 `~/Music`，启动不扫 |
| 本地 HTTP API | 开或关 `127.0.0.1:17890` | 默认关。只监听本机。关掉不影响 MCP。界面给出端口，并可复制 Base URL |
| 登录时启动 | 开机后以菜单栏形态待命 | 阶段 8 之前这项灰显或隐藏，不能真的写成登录项。在此之前 bundle id 仍是样例 id |
| 外观 · Deep Space | 只读说明 | MVP 不能换主题 |
| 清除指纹缓存 | `NSAlert` 二次确认，文案写明旧 id 全部失效 | 确认后清空指纹与曲目索引。不删音频文件。播放列表留着，里面的旧 id 显示为文件缺失 |

### 预览里不要当成产品行为

`index.html` 顶部的「空曲库 / 菜单栏 / 窗口约定」只用于翻设计稿，应用里没有这三个按钮。预览里的「添加曲目…」会把示例曲目全部塞进列表；正式的添加曲目是从曲库挑选。预览里的扫描只出现完成提示，不读磁盘。预览不播放音频，进度是本地计时。

---

## 视觉 token 与还原底线

视觉参考工程亦名 Lyria（`/Users/qianxiao/worker/reactactive/Lyria`）与其 Deep Space 设计；参考 Figma：https://www.figma.com/design/03wRSSJiiPqcdZI3hiEsmn/Lyria 。那是设计参考；本产品是同品牌的 macOS 本地播放器，形态仍是窗口 + 菜单栏，不套用参考工程的移动双 Tab。本仓库交付稿见 Figma `JJFaj1UysoberBKEr8G8Jc` 与 `.design/ui-mocks/`。

| Token | 值 |
| --- | --- |
| 背景 | `#0a0b1a` |
| 强调色 | `#9b87f5 → #7c3aed`（渐变/悬停） |
| 圆角 | 16–24px |
| 材质 | 侧栏/卡片用 Deep Space 实色或同色玻璃；禁止 behindWindow vibrancy（会吸壁纸色）；左右同底色 `#0a0b1a` |
| 曲目列表 | 与导航标题、搜索、底栏左右对齐。行间一条淡分割线；正在播放的行用强调色。行内见「曲目行」 |
| 图标 | SwiftUI 使用 SF Symbols，线型与侧栏一致，颜色跟随文字。HTML 预览用 Lucide 对齐同一套语义 |

字体跟随系统 SF；列表次要信息降低对比；封面圆角略小于卡片。深色为默认；设置里外观说明写死 Deep Space（MVP 不做多主题切换）。

> **视觉还原底线（已锁定）** — 尽量贴近设计；不承诺与参考 Lyria Web/Figma 像素级一致。SwiftUI 优先；毛玻璃、细阴影等难贴处允许 AppKit 补刀（如 `NSVisualEffectView`）。验收：同场景截图对照草图/参考，差一大截改 token 与布局，不硬撑。

---

## 空态与错误态

| 场景 | 表现 |
| --- | --- |
| 空曲库 | 文案「还没有音乐」· CTA「扫描曲目」/「打开设置」· 底栏无曲时置灰 |
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
| 传输 | 客户端侧 **stdio**（薄桥）；App 内为 **Unix domain socket**（Application Support API → `Lyria/mcp.sock`；死 sock unlink；桥 ≤3s 退避）接到同一份引擎。不经 HTTP。进程模型见上文「已锁定」节 |
| 错误 | 引擎宕机/缺文件/坏参数/桥无法附着 → 明确错误；永不假成功；不得把「已开始加载」报成 ok |
| 不做 | 截图、桌面驱动类工具；不在桥进程内起第二份引擎 |

| 工具 | 参数 | 说明 |
| --- | --- | --- |
| `lyria_status` | — | 当前曲、playing、位置/时长、shuffle、repeat、volume、队列长度 |
| `lyria_play` | `id?` **XOR** `uri?` | `id` → 库内 `.track`；`uri: file://…` → `.oneShot`（不入库、不分配 `trk_`）；**二者都空** = resume；**二者同时有** = 参数错误 |
| `lyria_pause` | — | 暂停；重复调用幂等返回当前状态 |
| `lyria_toggle` | — | 播放/暂停切换 |
| `lyria_next` | — | 下一首 |
| `lyria_previous` | — | 上一首 |
| `lyria_seek` | `positionMs` | 毫秒 seek |
| `lyria_shuffle` | `enabled: bool` | 幂等 |
| `lyria_repeat` | `mode: off\|all\|one` | 幂等 |
| `lyria_search` | `q` · `limit?` | 搜曲库 |
| `lyria_queue_list` | — | 当前队列 |
| `lyria_queue_add` | `id?` **XOR** `uri?` · `position?: next\|end` | 入队；语义同 `lyria_play` 的 id/uri；缺一不可（须恰好一个） |
| `lyria_queue_clear` | — | 清空队列 |

响应 JSON 与 HTTP 同形。`lyria_status` 示例字段含 `ok`、`track`（**库内曲：** `id`/`title`/…；**oneShot：** `id: null` + 必填 `uri` + 展示字段）、`playing`、`positionMs`、`durationMs`、`shuffle`、`repeat`、`volume`、`queueLength`。`lyria_play` 失败示例：`error=not_found`，`message=track id not in library`。**一次性点播**只走 `uri: file://…`（无库 id / 无新 `trk_`；status 见上），与正文 `QueueItem.oneShot` 一致。客户端 stdio 配置指向 **薄桥**（`lyria-mcp` 或 `Lyria --mcp`），由桥附着到已运行的 App（socket 见上）；具体 bundle 路径在阶段 3 写入 README。

> MCP 尚未开工：需另说「开工」后再实现；**进程模型已锁定为薄桥 + 单实例**，实现不得改回「每客户端一份引擎」。

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
| POST | `/play` | `id?` **XOR** `uri?`（同 MCP）；二者都空 = resume；二者同时有 = 400 | 是 |
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
| POST | `/queue` | `id?` XOR `uri?` · `position?: next\|end` | 是 |
| DELETE | `/queue` | 清空 | 是 |
| DELETE | `/queue/:index` | 按索引删 | 可选 |

MVP HTTP = health + status + 传输六件套（play/pause/toggle/next/previous/seek）+ shuffle/repeat + search + queue 读写。浏览类列表进批次 2。`file://` uri 点播不创建库 id。端口 `17890` 不变。

> HTTP 尚未开工；可关且不得拖垮 MCP。

---

## 设置

- 曲库扫描不在设置里。空曲库「扫描曲目」选择唯一根（不预置 `~/Music`，多根延后）并增量扫描。进度条在曲库页，可取消
- HTTP API 开/关 · 端口 · 复制 Base URL
- **登录时启动：** **阶段 8 之前不做**；设置项灰显或隐藏。启用 `SMAppService` 前须把工程 bundle id 从样例 `local.lyria.sample` 换成稳定 id（文档目标：**`app.lyria.macos`**——**仅规格锁定，当前不改 pbxproj**）。ad-hoc 签名 + sample id **不是**可用的登录项路径
- 外观说明：Deep Space（MVP 只读说明）
- 危险区：清空指纹库（`NSAlert`，文案写明「旧 id 全部失效」）

---

## 开发阶段

静态壳已落地。**2026-11-09 起阶段 2（曲库）先于阶段 1（引擎）开工**：本地扫描、指纹和 SQLite 接进现有壳。引擎 / MCP / HTTP / MenuBarExtra 仍停放。假数据目录已删除。每阶段结束有可验证产物再进下一阶段。

| # | 阶段 | 状态 | 备注 |
| --- | --- | --- | --- |
| 0 | Scaffold Xcode/SPM macOS App（Lyria） | **已完成** | 静态壳样例已在 `lyria`；完整工程结构可继续收 |
| 0b | 静态壳视觉与窗口逻辑 | **已完成** | Music 式标题栏行为 + Deep Space；细节可继续抠 |
| 2 | Library 扫描 + 指纹/id DB | **本切片** | 先于引擎。单根、不自动扫描、不预置 `~/Music`、硬删除曲目、保留指纹、播放控件置灰 |
| 1 | Engine + 本地文件试播烟雾 | 待开工（决策已锁） | 另需「开工」· Amb-1…19 已锁；AVPlayer + 菜单「试播…」→ OpenPanel → oneShot；`Sources/Lyria/Engine/`；人工听有声 |
| 3 | MCP 烟雾（薄桥 + `lyria_status` / `play` / `pause` / `search`） | 待开工 | 另需开工 · Application Support API socket · 死 sock unlink · 桥退避 · 无实例**带窗**拉起 · Dock 只激活 · server name `lyria` · **与主窗口**同状态（**不含**菜单栏） |
| 4 | Queue + shuffle/repeat | 待开工 | ended 行为正确 |
| 5 | 主窗 UI 对齐（艺人/专辑/歌单/设置/空态/队列等） | 待开工（Amb-UI 已锁） | **优先**· Amb-UI-1…16；假数据可点全主窗；真 MenuBarExtra 仍=阶段 8；须 UI「开工」 |
| 6 | 空态/错误态 | 待开工 | 按锁定文案 |
| 7 | 可选 HTTP 层 | 待开工 | 可关且 MCP 仍好 |
| 8 | 菜单栏 + 设置打磨 | 待开工 | popover 与主窗口传输状态一致；登录项策略见上 |
| 9 | 真机证明清单 | 待开工 | 见验收 |

### 阶段门闩

1. **阶段 0 门闩** — 静态壳已放行。完整引擎/MCP 另需明确开工；配 CloudAgent 前确认 GitHub remote。无 remote 则只本地 git。
1b. **UI 对齐证明（Amb-UI）** — 用户对 UI 说「开工」后：主窗假数据可点（曲库/艺人/专辑/歌单/设置/空态/队列）；侧栏圆角卡、page-head、三栏传输、Dreamscape FakeData、无 subtitle、Spec 空态文案、HTTP stub 显示关、SF Symbols；截图对照 HTML 原型结构贴近即可（非像素级）。**不含**真引擎/MCP/MenuBarExtra。
2. **阶段 1 证明** — 菜单「试播…」→ `NSOpenPanel`（MVP UTType）→ `QueueItem.oneShot` / `play(uri: file://…)`（**不**入库、**不**另开 path-only API），**本机人工听**有声；`TransportState` 时钟前进（2–4 Hz observer）；启动 `playing=false`/`current=nil`；失败走 Alert/`lastError`；`ended`→pause。状态机 / 命令串行可单测；**无 CI 音频回归**。决策清单见「阶段 1 已锁决策」。
3. **阶段 2 前** — Package 补 `LyriaCore` + `LyriaTests`（至少 Crockford 全零向量 → `trk_0000000000000000000000`）；与 xcodeproj 同步（**阶段 1 不建 Core** · Amb-12）。
4. **阶段 3 证明** — 先开 `Lyria.app`，再用 MCP 客户端经薄桥调 `lyria_search` → `lyria_play(id)` → `lyria_pause`；**主窗口**传输状态与 MCP 一致（**不要求**菜单栏；菜单栏归阶段 8）。无实例时桥**带窗**拉起同一二进制后工具仍可用。故意再起第二个 GUI 不得出现第二份引擎。
5. **阶段 7 证明** — 关掉 HTTP 开关后再走一遍 MCP，行为不变。
6. **阶段 8** — 菜单栏 popover 与主窗口传输状态一致；稳定 bundle id（目标 `app.lyria.macos`）就绪后，才做登录项 / `SMAppService`；此前设置项灰显或隐藏。

---

## 验收标准

- [ ] 在 M1 Pro 上成功编译运行 Lyria
- [ ] 播放真实本地音频文件（非静音 fake）
- [ ] MCP 经薄桥附着：`lyria_play` / `lyria_pause` / `lyria_search` 可用，且与主窗口同一份 `TransportState`（菜单栏一致性见阶段 8）
- [ ] 同时开窗口 + MCP 客户端时只有一份引擎/曲库（无第二进程播放状态）
- [ ] 文件重命名后同一指纹仍映射同一 `trk_`
- [ ] HTTP 关闭时 MCP 仍完整工作
- [ ] 空曲库/空歌单/不可播/引擎不可用态符合锁定文案
- [ ] 菜单栏与主窗口传输状态一致

---

## 风险与未决

| 项 | 说明 | 状态 |
| --- | --- | --- |
| GitHub remote | [Ever12349/lyria](https://github.com/Ever12349/lyria) 已创建；CloudAgent 需 Cursor 对该仓的访问授权 | 仓已有 / 访问待授 |
| 仓库文件夹名 | 磁盘路径已为 `/Users/qianxiao/worker/AIAgent/lyria`（由原 `vinyl` 更名） | 已落地 |
| 曲库根 | MVP **单根**，不预置 `~/Music`（未选显示「未选择」）；多根延后 | **2026-11-09 覆盖** |
| 增量扫描 | path + size + mtime 快路径。UI 不暴露强制重扫；`force` 仅留在扫描器里 | **已锁** |
| FLAC | 系统 AVFoundation 不能播则跳过 + 明确错误；**非目标：第三方 FLAC 解码器** | 接受的平台限制 |
| App Sandbox（已锁 · C2） | 个人自用 MVP **关闭** App Sandbox（与当前工程无 entitlements / 无 `ENABLE_APP_SANDBOX` 一致）。日后若上架或开沙盒，必须 security-scoped bookmark。`scan_roots.bookmark` **仍从第一天就写**（阶段 2 落库），避免日后开沙盒时路径全废 | **已锁：关** |
| 艺人/专辑 id 命名空间 | NFC+空白折叠；`encoding_suspect` MVP **仅 U+FFFD**（可选 U+0080–00FF 启发须排除 CJK/假名/谚文码点）；suspect → id NULL，禁伪 `suspect:` 键与「前往艺人/专辑」；`alb_` = artist+`\0`+album；无完整 GBK 分类器 | **已锁** |
| 大文件指纹阈值 | ≥ 32 MiB → head_tail_size；不得事后改 | **已锁** |
| Crockford 测试向量 | 16 字节全零 → `trk_0000000000000000000000`；Package 需 `LyriaCore`+`LyriaTests`，与 xcodeproj 同步 | **已锁**（仓库尚无 test target） |
| 队列项模型 | `track(trk_)` 或 `oneShot(file://)`；阶段 1 起；oneShot 的 status.`track.id` = `null` + 必填 `uri` | **已锁** |
| MCP 工具 id/uri | `lyria_play` / `lyria_queue_add`：`id?` XOR `uri?`；一次性点播走 `file://` | **已锁** |
| SQLite | 系统 SQLite3 + 薄 `Database.swift` / `user_version`；不上 GRDB | **已锁** |
| 引擎写入模型 | 单一 PlaybackEngine/actor 串行命令；play 成功等 readyToPlay | **已锁** |
| 标题栏穿透 | 穿透带收窄；浮层走系统 sheet/popover；每加顶栏交互真机回归 | **已锁策略** |
| 曲目行手势 | 选中/双击/封面按钮/共用菜单拆分；歌单重排整表改 position | **已锁策略** |
| 无缝换曲 | 不进验收 | **已锁** |
| 视觉还原 | 已锁：尽量贴 + AppKit 补刀；非像素完美。不走 Web 壳除非用户改口 | 已锁 |
| MCP 进程模型 | 薄桥（stdio↔Unix socket）+ App 单实例单引擎；对标 Cog / Xcode mcpbridge。禁止每 MCP 客户端一份引擎 | **已锁** |
| 无实例拉起 | 阶段 3：始终**带窗**拉起同一二进制；Dock 只激活；无头/LSUIElement 延后 | **已锁** |
| IPC 载体 | **仅** Unix domain socket：Application Support API → `Lyria/mcp.sock`；listen 前 unlink 死 sock；桥 ≤3s 退避；同二进制/--mcp 共路径；XPC/Mach = 非目标 | **已锁** |
| 登录项 | 阶段 8 前不做（设置灰显/隐藏）；此前须稳定 bundle id（目标 `app.lyria.macos`，**暂不改 pbxproj**）；ad-hoc+`local.lyria.sample` 不可用 | **已锁策略** |
| `user_hidden` | **2026-11-09 取消。** 从曲库移除改为硬删除 `tracks` 行；指纹保留；歌单引用级联删除；封面删除；空艺人/专辑行删除 | **覆盖** |
| iCloud vs tombstone | 已在库的占位 = 见过，不 `missing`（可选 `icloud_offline`）；真删除才 tombstone | **已锁** |
| `aliases_json` | MVP **必须**持久化；删除「可先只打日志」；自动切主路径依赖它 | **已锁** |
| 阶段 3 vs 菜单栏 | 阶段 3 只验主窗口↔MCP；菜单栏同步 = 阶段 8 | **已锁** |
| HTTP `POST /play` | 与 MCP 相同：`id?` XOR `uri?` | **已锁** |
| 有声验收 | 阶段 1 门闩 = 本机人工听；TransportState/命令串行可单测；无 CI 音频回归 | **已锁** |
| 阶段 1 决策 Amb-1…19 | 初始音量 1.0；`NowPlaying`；错误码六件套；`@Observable`；`Sources/Lyria/Engine/`；传输绑引擎/列表可暂 FakeData；2–4 Hz observer；失败 Alert+lastError；Queue 仅当前项；actor→MainActor；删 subtitle；无 LyriaCore；bundle 保持 sample；菜单试播；轻量标签；MVP UTType；ended→pause；状态存 ms；启动无假 nowPlaying | **已锁** |
| Amb-20（阶段 2/3） | MCP 远程开关默认、桥 `--mcp` vs 独立 target、`sort_name`、空艺人展示、encoding fixture | **延后** · 不挡阶段 1 |
| Amb-UI-1…16（主窗 UI） | 范围 B 全主窗假数据；Spec 空态文案；Dreamscape FakeData；假队列；三栏传输；封面/更多假动作；侧栏圆角卡；完整 page-head；设置六行 stub；repeat 三态；UI 阶段假 now-playing；搜索+returnTo；pill toast；HTTP stub 显示关；仅 SF Symbols；无真 MenuBarExtra | **已锁** · UI 另需「开工」 |

**约束重申：** **UI 优先**（Amb-UI-1…16 已锁文档；改 UI Swift 须对 UI 说「开工」）；**引擎 / MCP 停放**（Amb-1…19 仅锁文档；另需开工）；阶段 1 试播走已锁 C1 + Amb 清单；MVP 沙盒已锁关闭（C2）且仍写 `scan_roots.bookmark`；MCP 实现必须遵守已锁的薄桥 + 单实例模型；CloudAgent 需 Cursor 已授权访问 `Ever12349/lyria`；agent 面是 MCP/HTTP，不是截图。设计资产以 `.design/` 为准；HTML 原型 = 壳层视觉真源。

---

*本文档由 Canvas「Lyria 全流程开发文档」导出并按正式路径 `…/AIAgent/lyria` 更新；2026-11-07 锁定 MCP 薄桥 + 单实例、指纹阈值/规范化、队列项、引擎单写者、标题栏/曲目行策略；同日续锁 socket/带窗/encoding/MCP id-uri/SQLite3/单根增量/登录项/Crockford/有声门闩；同日再锁：encoding_suspect 仅 U+FFFD、`alb_` 艺人+专辑、`user_hidden`、iCloud≠tombstone、aliases 必持久化、oneShot `id:null`、socket API+unlink+退避、阶段 3 不含菜单栏、`POST /play` XOR；同日详情列改为导航标题（可带后退）与搜索、列表、底栏对齐，曲目行改为淡分割线，封面占位按专辑区分；同日写入「控件操作与限制」；同日再锁 C1 试播入口（OpenPanel→oneShot）与 C2 App Sandbox=关；同日用户确认 Amb-1…19 全部按建议锁入「阶段 1 已锁决策」（仍未写 Swift）；同日用户确认 Amb-UI-1…16 全部按建议锁入「UI 已锁决策」（仍未写 Swift；UI/引擎分开开工）。2026-11-09 曲库切片开工：阶段 2 先于阶段 1；取消 `user_hidden`；移除即硬删除并保留指纹；不预置 `~/Music`、启动不扫描；播放控件置灰。交互式版本：[Canvas](https://cursor.com/canvas/store-669ca32f-ae0c-4bc0-be04-6e46150cff28/37c89944-4d8d-4256-b8f6-e516d782a9f4)。*
