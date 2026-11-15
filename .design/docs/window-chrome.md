# Lyria · Window Chrome（原生标题栏约定）

视觉与窗口行为以 Deep Space 样例 + 系统「音乐」式原生标题栏为准。完整规格见 [`docs/dev-spec.md`](../../docs/dev-spec.md)「窗口与壳层逻辑」。

## 视觉锁定

- Deep Space 底色 `#0a0b1a`；Accent `#9b87f5 → #7c3aed`
- 左右栏**同色**深空底，禁止吸壁纸 vibrancy
- 主窗约 `1180×760`，圆角 `16–24`
- 侧栏卡四角圆角 18px，左 / 上 / 下各留约 12px 外边距。红绿灯落在卡顶空白带里，品牌文案在红绿灯下方
- 侧栏卡底边高于窗口底约 12px；底栏 Transport **只在详情列**，不延伸到侧栏下
- 无自定义黑色顶栏条

## 原生窗口逻辑（实现契约）

1. `NSWindow.styleMask` 含 `.titled` + `.fullSizeContentView`
2. `titlebarAppearsTransparent = true`、`titleVisibility = .hidden`
3. 红绿灯仍是系统 `standardWindowButton`，布局后把原点移进 12px 内缩侧栏卡的顶部空白带（圆角 18）；不自绘假按钮。拖动 / 双击放大还原走系统 `NSThemeFrame`
4. **不**自定义 `NSEvent` 监听双击，**不**手调 `performZoom`
5. SwiftUI 内容会盖住标题栏命中区。侧栏穿透仍是系统标题栏拖动带（约为 `frame` 与 `contentLayoutRect` 的高度差，落空时约 28pt）；详情列标题行（标题、搜索等）的空白处同样穿透，点在搜索、返回、批量按钮上则不穿透。勿把整窗顶 52pt 一律 `hitTest → nil`。列头和扫描条不在标题栏内、不穿透。
6. 侧栏可拖宽 **168–320**（默认 ~228）

## 设计交付

- Figma: https://www.figma.com/design/JJFaj1UysoberBKEr8G8Jc
- PNG mocks: `.design/ui-mocks/`（01–14）
- Canvas: https://cursor.com/canvas/store-669ca32f-ae0c-4bc0-be04-6e46150cff28/37c89944-4d8d-4256-b8f6-e516d782a9f4
