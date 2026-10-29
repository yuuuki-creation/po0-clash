# macOS 原生版

SwiftUI 菜单栏应用，代码在 `apps/macos`，方案见 [native-rewrite.md](native-rewrite.md)。

## 结构

- SwiftPM 包（`apps/macos/Package.swift`），最低 macOS 13，`LSUIElement`（不显示程序坞图标）。
- 菜单栏窗口（`MenuBarExtra`，`.window` 样式）：连接开关与状态、出口 IP、速率、模式、虚拟网卡 / 系统代理、订阅切换、
  策略组与延迟测试、加白总开关。另有一个工具栏标签式的设置窗口：通用（开机自启、导出诊断日志）、订阅、加白。
- 内核调用全部经过 `CoreClient.swift`，在后台队列执行；引擎与路由命令走同一个串行队列，保证按用户操作顺序生效。
- 按 HIG 的液态玻璃规范：用 macOS 26 SDK 构建，系统控件、菜单栏窗口、工具栏与弹出表单自动获得液态玻璃；只有浮动的
  控件层（菜单底部的按钮栏、「重新连接」）额外用 `.glass` / `.glassProminent` 与 `GlassEffectContainer`。内容一律放在
  不透明的分组表面上（设置窗口用 `.formStyle(.grouped)`），用系统背景色、系统强调色与语义色，不加渐变、彩色背景或
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
   `-showSettings <tab>` 打开界面，`-appearance dark` 强制深色（runner 的系统外观改不了），`-AppleLanguages '(zh-Hans)'`
   切中文。
