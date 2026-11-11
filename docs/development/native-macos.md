# macOS 原生版

Swift 外壳（主窗口加菜单栏），代码在 `apps/macos`，方案见 [native-rewrite.md](native-rewrite.md)。主窗口的界面是
`apps/windows` 的网页（React + MUI），与 Windows 版共用，跑在 `WKWebView` 里；内核、菜单栏、全局快捷键、虚拟网卡授权、
开机自启、旧数据导入和更新检查仍由 Swift 负责。

## 结构

- SwiftPM 包（`apps/macos/Package.swift`），最低 macOS 13，`LSUIElement`；主窗口打开时切成普通应用（显示程序坞图标），
  关闭后回到只在菜单栏。正常打开应用、再次打开或点程序坞图标时显示主窗口，开机自启时不显示。
- 主窗口（`MainWindow.swift`）：AppKit 管理的窗口，隐藏标题栏、内容占满整个窗口，红绿灯留在系统默认位置，最小 900×600。
  内容是一个 `WKWebView`，`WebAssets` 用自定义协议把应用包里的 `Contents/Resources/web` 提供为 `po0://app/…`
  （不是文件的路径回落到 `index.html`）。页面顶部留 36 pt 给红绿灯，带 `data-tauri-drag-region` 的区域按下时发
  `window_drag`、双击时发 `window_zoom`。页面的脚本错误和加载结果写进系统日志（`web error: …`、`web interface loaded`）。
- 桥（`Bridge.swift`、`Wire.swift`）：页面调用
  `window.webkit.messageHandlers.po0.postMessage({cmd, args})`，得到结果的 JSON 字符串（无返回值时是 `"null"`），失败时
  Promise 以错误信息拒绝。命令名、参数名和 JSON 结构与 Windows 的 Tauri 命令
  （`apps/windows/src-tauri/src/shell/commands.rs`）一致，即 serde 对 `crates/core` 类型的输出；`Wire.swift` 逐字段在
  UniFFI 类型与这份 JSON 之间转换，内核类型增减字段时两边要一起改。不实现 Windows 专用的 `loopback_apps`、
  `set_loopback`；macOS 另有 `check_update`、`window_drag`、`window_zoom`、`set_window_background`、`write_clipboard`。
  - `start`、`set_route_mode` 走虚拟网卡授权流程；`set_route_mode` 被取消授权时以错误返回，接管方式不变。
  - `backup_to_file`、`restore_from_file`、`export_profile`、`export_diagnostics` 用系统的存取面板（挂在主窗口上的表单）。
  - `set_app_settings`、`set_engine_options` 缺少的字段保持当前值（Windows 上是取默认值）。
- 事件：Swift 调用 `window.__po0Emit(事件名, 载荷)`。内核的每次变更发 `core-change`（`status`、`profiles`、`groups`、
  `whitelist`），所以菜单栏和快捷键的操作也会到达页面；菜单栏一侧出现的错误提示发 `shell-error`；菜单或启动参数要求打开
  某一页时发 `navigate`（页面名）。
- 菜单栏窗口（`MenuBarExtra`，`.window` 样式）作为快捷入口：连接开关与状态、出口 IP、速率、模式、虚拟网卡 / 系统代理、
  订阅切换、策略组与延迟测试、加白总开关，底部按钮打开主窗口。它是 SwiftUI 画的，文案在
  `Resources/*.lproj/Localizable.strings`（简体中文、英文、日文、俄文）；主窗口的文案在网页里。
- 内核调用全部经过 `CoreClient.swift`，在后台队列执行；引擎与路由命令走同一个串行队列，保证按用户操作顺序生效。
- 免责声明、发现新版本和 `clash://install-config` 链接的确认仍是系统的 `NSAlert`；启动保护的提示由页面通过
  `launch_notice` 取走后显示。

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
   构建 darwin 版 mihomo，在 `apps/windows` 里 `npm ci && npm run build` 并把 `dist` 复制为 `Contents/Resources/web`，
   组装通用的 `po0-clash.app` 并 ad-hoc 签名，打包成 `dist/po0-clash-macos.zip`，另外编出通用的检查工具 `dist/po0-e2e`；
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
5. `-showWindow dashboard` 打开主窗口，在系统日志里确认页面加载完成；页面报出脚本错误时只给警告；
6. 仅 macos-26：截图。`-launchedAtLogin YES` 模拟开机自启（必须自动重连）、`-testDelays YES` 先测延迟、`-showMenu YES` /
   `-showWindow <页面名>` 打开界面，`-appearance dark` 强制深色（runner 的系统外观改不了），`-AppleLanguages '(zh-Hans)'`
   切菜单栏的语言。
