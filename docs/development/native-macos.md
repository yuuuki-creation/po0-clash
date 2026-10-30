# macOS 原生版

SwiftUI 应用（主窗口加菜单栏），代码在 `apps/macos`，方案见 [native-rewrite.md](native-rewrite.md)。

## 结构

- SwiftPM 包（`apps/macos/Package.swift`），最低 macOS 13，`LSUIElement`；主窗口打开时切成普通应用（显示程序坞图标），
  关闭后回到只在菜单栏。正常打开应用、再次打开或点程序坞图标时显示主窗口，开机自启时不显示。
- 主窗口（`MainWindow.swift`，ADR 0019）照访达布局：AppKit 管理的窗口里放 `NavigationSplitView`，侧边栏与 Flutter 版一致，依次为仪表盘、
  代理、配置、加白、活动、工具；内核还没支持的工具项和活动页先显示「即将推出」（ADR 0020）。从 macOS 14 起 `NSHostingController` 把 SwiftUI 的 `.toolbar`、`.navigationTitle` 和
  `.navigationSubtitle` 桥接到窗口的统一工具栏，页面操作是纯图标按钮，macOS 26 上由系统放进共用的玻璃胶囊；macOS 13
  不能桥接，改为内容顶部的标题行，侧边栏也不允许收起。仪表盘是 FlClash 式的卡片网格（速率、出口 IP、当前节点、模式、
  接管方式、订阅用量、加白，填充与分组表单相同）和右下角的浮动启动按钮（已连接时显示时长）；代理页是策略组标题加节点
  卡片网格；订阅、加白、设置是 `.formStyle(.grouped)` 表单；空页面用 `ContentUnavailableView`，提示用标准弹窗。
- 菜单栏窗口（`MenuBarExtra`，`.window` 样式）作为快捷入口：连接开关与状态、出口 IP、速率、模式、虚拟网卡 / 系统代理、
  订阅切换、策略组与延迟测试、加白总开关，底部按钮打开主窗口。
- 内核调用全部经过 `CoreClient.swift`，在后台队列执行；引擎与路由命令走同一个串行队列，保证按用户操作顺序生效。
- 按 HIG 的液态玻璃规范：用 macOS 26 SDK 构建，系统控件、菜单栏窗口、工具栏与弹出表单自动获得液态玻璃；只有浮动的
  控件层（启动按钮、「重新连接」、菜单底部的按钮组）额外用 `.glass` / `.glassProminent` 与 `GlassEffectContainer`。
  内容层不用玻璃，用系统背景色、系统强调色与语义色，不加渐变、彩色背景或
  自绘模糊。更早的系统使用默认外观。
- 界面语言跟随系统，简体中文与英文（`Resources/*.lproj/Localizable.strings`）。

## 数据与迁移

- 内核数据目录：`~/Library/Application Support/io.github.yuuukicreation.po0clash/core`，与 Flutter 版的文件分开。
- Flutter 版没有启用沙盒，数据就在上一级目录。首次启动时把其中的 `database.sqlite` 交给内核；Flutter 在 macOS 上把
  shared_preferences 存在本应用 ID 的 `UserDefaults` 里（`flutter.*` 键），应用把这些键导出成
  `core/legacy_shared_preferences.json`（与桌面其它平台的 `shared_preferences.json` 同格式）再交给内核。

## 虚拟网卡

不用 Network Extension（ADR 0018）。选择虚拟网卡、或以虚拟网卡模式连接时，如果
`/Library/Application Support/io.github.yuuukicreation.po0clash/mihomo` 不存在、不是 root 所有的 setuid 文件，或与包内
mihomo 的 SHA-256 不同，就弹一次管理员授权，复制并设为 `root:wheel 4755`，然后把该路径交给内核。用户取消时退回系统代理。
系统代理模式始终使用包内的 mihomo。

## 安装

`scripts/install-macos-native.sh`（用法见 [install.md](../install.md)）：从 `native-v*` 发布下载 `po0-clash-macos.zip`
（不带版本时取最新的一个，包括测试版），核对 SHA-256、应用 ID、架构和签名；退出正在运行的副本（原生版发 SIGTERM，
Flutter 版先发正常退出的 Apple 事件，再退回 SIGTERM，并结束它包内的 `Po0ClashCore`），替换 `/Applications/po0-clash.app`，
移除隔离属性后打开。数据目录不动，原生版首次启动时导入 Flutter 版的订阅和加白 token。

## 构建与测试

不在本机构建。推送 `native*` 分支后由 `.github/workflows/native-macos.yaml` 运行。

`build`（macos-26）：

1. `cargo test -p po0-core`；
2. `WITH_E2E=1 ARCHS="arm64 x86_64" apps/macos/scripts/bundle.sh`：构建 `po0-ffi` 静态库、用宿主 debug 库生成 Swift 绑定、
   构建 darwin 版 mihomo，组装通用的 `po0-clash.app` 并 ad-hoc 签名，打包成 `dist/po0-clash-macos.zip`，另外编出通用的
   检查工具 `dist/po0-e2e`；
3. 用刚构建的 mihomo 跑内核的真实引擎测试，上传应用和检查工具。

`check`（macos-26、macos-14、macos-15-intel 各一份，只下载产物、不编译；GitHub 已不提供 macOS 13）：

1. 安装：先放一个假的 Flutter 版（同一应用 ID、正在运行的进程和 `Po0ClashCore`）和它的旧数据，用安装脚本的本地 zip
   模式安装，确认旧进程已退出、订阅和加白 token 已导入；再通过本地模拟的 GitHub API 各装一次（不带版本 / 带版本），
   确认选中的发布、SHA-256 校验和应用重启；
2. `apps/macos/scripts/e2e.sh`：本机起 shadowsocks 节点（第二个 mihomo，出站绑定物理网卡）和带用量头的 HTTP 订阅，
   `po0-e2e` 用真实绑定添加订阅、导入分享链接，依次以系统代理、虚拟网卡（sudo 执行与应用相同的安装命令）、再以系统代理
   连接，每次都在节点日志里确认请求经过了节点；最后测延迟、写入加白条目，数据留在应用的数据目录里；
3. 普通启动 10 秒，确认没有自动连接、SIGTERM 后正常关闭；
4. `-showMenu YES -reopenMenu YES` 打开、关闭、再打开菜单窗口，在系统日志里确认刷新了至少两次；
5. 仅 macos-26：截图。`-launchedAtLogin YES` 模拟开机自启（必须自动重连）、`-testDelays YES` 先测延迟、`-showMenu YES` /
   `-showWindow <dashboard|proxies|profiles|whitelist|activity|tools>` 打开界面，`-appearance dark` 强制深色（runner 的系统外观改不了），`-AppleLanguages '(zh-Hans)'`
   切中文。
