# 0022. 桌面端界面改用 Clash Verge Rev 的样式，Android 改用 FlClash 的样式

- 状态：已采纳
- 日期：2026-11-11

## 背景

维护者要求 Windows 和 macOS 的界面与 Clash Verge Rev 一样，Android 的界面与 FlClash 一样；允许更换界面框架，但不改 Rust 代码；
三端都要能检查更新。

## 决定

- **桌面端共用一套网页界面**，代码在 `apps/windows/src`：React、MUI、TypeScript、valtio。布局、配色、基础组件和各页面的版式照
  Clash Verge Rev 做：左侧是标志、导航和流量区，右侧是带标题栏的页面；导航为首页、代理、订阅、加白、连接、规则、日志、设置。
  Clash Verge Rev 没有的功能（加白）用同一套组件，它有而内核没有的功能不做。
- **Windows** 仍是 Tauri 外壳，Rust 部分不变。
- **macOS** 的主窗口换成 `WKWebView`，加载同一份网页；Swift 外壳保留菜单栏窗口、快捷键、虚拟网卡授权和内核调用，并通过
  消息桥提供与 Windows 外壳同名、同 JSON 结构的命令。不引入 Tauri，因为那需要新的 Rust 外壳。
- **Android** 保留 Kotlin 与 Jetpack Compose，界面层按 FlClash 重做：底部导航与 FlClash 的页面结构。8.1.0 起以 [FlClash 0.9.3](https://github.com/chen08209/FlClash/tree/v0.9.3) 为基准：纵向仪表盘卡片、顶部状态卡内的启动按钮、上下行分开的速度面板、代理组胶囊标签；连接卡片不能隐藏。
- **更新检查**：macOS 和 Android 调内核的 `check_update`。Windows 外壳没有这个命令，由网页直接请求 GitHub 的发布列表，
  版本比较规则与 `crates/core/src/update.rs` 相同（`apps/windows/src/lib/version.js`）。
- **图标**：莫兰迪色系的平涂图标：雾蓝底，米白竖笔和灰粉圆碗叠成小写 p，重叠处是第三种颜色；托盘和菜单栏用单色字形。三端的位图由 `tool/make_icons.py` 生成，
  矢量版在 `assets_source/images/icon`。Flutter 版的图标不动。
- **许可证**：Clash Verge Rev 和 FlClash 都是 GPL-3.0，与本仓库相同。照其源码改写的文件在文件头注明来源，README 和应用内的
  开源许可页写明致谢。

## 后果

- 取代 ADR 0021 的全部样式决定，以及 ADR 0018 中「macOS 用 SwiftUI 画主窗口」「Windows 界面不引入组件库」两点。
- macOS 主窗口的 SwiftUI 页面删除；两个桌面端的界面只需改一处。
- macOS 的消息桥要手工保持与 serde 输出一致，内核类型变化时两边都要改。
- 默认强调色改为 Clash Verge Rev 的蓝色（浅色 `#007AFF`，深色 `#0A84FF`）；用户选过的强调色仍然生效。

## 8.1.0 更新（2026-11-12）

桌面端以 [Clash Verge Rev 2.5.10](https://github.com/clash-verge-rev/clash-verge-rev/tree/v2.5.10) 为基准，补齐首页卡片设置、窗口缩放与键盘操作。卡片显隐复用内核已有的 `dashboardCards`，保留其它卡片的设置，不扩充 Rust 或消息桥接口。

发版前检查实际应用与截图。Chromium / WebKit 的模拟检查覆盖两种桌面外观和页面操作，原生壳与 VPN 另行验证。
