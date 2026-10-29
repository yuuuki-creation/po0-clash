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

## 构建与测试

不在本机构建。推送 `native*` 分支后由 `.github/workflows/native-macos.yaml` 在 `macos-26` 上：

1. `cargo test -p po0-core`；
2. `apps/macos/scripts/bundle.sh`（CI 用 `ARCHS="arm64 x86_64"`）：构建 `po0-ffi` 静态库、用宿主 debug 库生成 Swift 绑定、
   构建 darwin 版 mihomo，组装通用的 `po0-clash.app` 并 ad-hoc 签名，打包成 `dist/po0-clash-macos.zip`；
3. 用刚构建的 mihomo 跑内核的真实引擎测试；
4. `apps/macos/scripts/e2e.sh`：在本机起一个 shadowsocks 节点（第二个 mihomo，出站绑定物理网卡）和一个带用量头的 HTTP
   订阅，`RealFlowTests` 用真实绑定添加订阅、导入分享链接，依次以系统代理、虚拟网卡（用 sudo 执行与应用相同的安装命令，
   得到同一路径的 setuid 内核）、再以系统代理连接，每次都在节点日志里确认请求经过了节点；最后测延迟、写入加白条目，
   数据留在应用的真实数据目录里；
5. 普通启动 10 秒，确认没有自动连接、SIGTERM 后正常关闭；
6. 截图：`-launchedAtLogin YES` 模拟开机自启（必须自动重连）、`-testDelays YES` 先测延迟、`-showMenu YES` /
   `-showSettings <tab>` 打开界面，`-appearance dark` 强制深色（runner 的系统外观改不了），`-AppleLanguages '(zh-Hans)'`
   切中文；截图与应用压缩包作为构建产物上传。
