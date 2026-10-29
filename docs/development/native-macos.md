# macOS 原生版

SwiftUI 菜单栏应用，代码在 `apps/macos`，方案见 [native-rewrite.md](native-rewrite.md)。

## 结构

- SwiftPM 包（`apps/macos/Package.swift`），最低 macOS 13，`LSUIElement`（不显示程序坞图标）。
- 菜单栏窗口（`MenuBarExtra`，`.window` 样式）：连接开关与状态、出口 IP、速率、模式、虚拟网卡 / 系统代理、订阅切换、
  策略组与延迟测试、加白总开关。另有一个工具栏标签式的设置窗口：通用（开机自启、导出诊断日志）、订阅、加白。
- 内核调用全部经过 `CoreClient.swift`，在后台队列执行；引擎与路由命令走同一个串行队列，保证按用户操作顺序生效。
- macOS 26 上部分卡片与按钮使用液态玻璃，更早的系统用默认外观。
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

## 构建与测试

不在本机构建。推送 `native*` 分支后由 `.github/workflows/native-macos.yaml` 在 `macos-26` 上：

1. `cargo test -p po0-core`；
2. `apps/macos/scripts/bundle.sh`：构建 `po0-ffi` 静态库、用宿主 debug 库生成 Swift 绑定、构建 darwin 版 mihomo，
   组装并 ad-hoc 签名 `po0-clash.app`，打包成 `dist/po0-clash-macos.zip`；
3. 用刚构建的 mihomo 跑内核的真实引擎测试；
4. 启动应用 10 秒确认不退出，发 SIGTERM 确认正常关闭，并检查内核日志；
5. 用启动参数 `-showMenu YES`、`-showSettings <tab>`（可加 `-AppleLanguages '(zh-Hans)'`）打开界面截图，
   截图与应用压缩包作为构建产物上传。

`ARCHS="arm64 x86_64"` 可构建通用二进制，CI 目前只构建 arm64。
