# 原生重写进度

计划见 [native-rewrite.md](native-rewrite.md)。本页记录 2026-10-29 第一轮暂停时的状态；第二轮已按各平台的「下一步」继续。

## 分支

| 分支 | 内容 | 状态 |
|---|---|---|
| `native` | 共享内核 `crates/core`、`crates/ffi`，mihomo 子模块，文档 | 已验证，三端的基础 |
| `native-macos` | `apps/macos`、`native-macos.yaml` | CI 通过，没有在真机上试过连接 |
| `native-windows` | `apps/windows`、`native-windows.yaml` | 能交叉编译、安装、启动；引擎冒烟测试没跑通 |
| `native-android` | `apps/android`、`mihomo/android` | 模拟器上完整走通过；液态玻璃改版后没有重测 |

三个平台分支都还没有合入 `native`。`native-android` 里有 WIP 提交和两次 merge，合入前先整理历史。

## 共享内核

已完成：设置、订阅下载与用量、分享链接导入、mihomo 配置生成（po0 直连规则、`route-exclude-address`、`po0-direct`
入口）、po0 与 ggy 加白调度、引擎控制（Unix 套接字 / 命名管道；Android 进程内的 libmihomo）、系统代理、滚动日志、
诊断导出、从 Flutter 版导入订阅和加白条目。UniFFI 的错误类型是 flat error，Kotlin 里是 `CoreException.Invalid(message)`。

验证：59 个单元测试；真实 mihomo v1.19.33 的集成测试（本地 shadowsocks 节点，覆盖启动、策略组、延迟测试、出口 IP、
模式切换、热重载、选节点、崩溃检测与重启）；真实 po0 接口的证书校验；Windows 交叉编译的 clippy；Android 发版构建。
Ubuntu 上的 `native-core.yaml` 通过，macOS 的 CI 里内核测试和真实引擎测试也通过。

三端第一轮反馈已在 8b84b14 处理：setuid 的 mihomo 用单独的 `mihomo-root` 目录，分享链接文件移出 `providers/`，崩溃记录移到
`run/`；首次启动就写出 `settings.json`；新增 `was_connected()`，开机自启后据此恢复连接；加白的最近结果跨重启保留；网络变化和
亮屏状态写日志；Android 诊断里的路由显示为 VPN。

仍待处理：Windows 下的引擎路径（命名管道、Job Object、系统代理、名为 `po0-clash` 的 TUN 网卡）只靠应用在测试虚拟机里的
冒烟测试覆盖，内核的集成测试目前只在 Unix 上跑。

## macOS

已完成（CI 验证；构建在 macos-26、Xcode 26.6、SDK 26 上，产物是 arm64 + x86_64 通用包）：

- SwiftPM 包，最低 macOS 13，不显示程序坞图标，中英文跟随系统，用真实内核绑定。
- 菜单栏窗口：连接开关与状态、当前节点、出口 IP、速率、模式、系统代理 / 虚拟网卡、切换订阅、选节点与测延迟、加白开关和摘要、
  失败时的「重新连接」。设置窗口三个标签：通用（开机自启、导出诊断、版本）、订阅、加白。
- 虚拟网卡：首次使用时用一次管理员授权把 mihomo 装到 `/Library/Application Support/io.github.yuuukicreation.po0clash/mihomo`
  （root:wheel、4755，SHA-256 与包内一致才复用），取消授权就退回系统代理。
- 开机自启后，如果用户上次是连接状态（内核的 `wasConnected()`），自动重新连接；手动打开不会自动连接。
- 菜单窗口每次打开都刷新（除了 onAppear 还跟踪窗口的遮挡状态）。
- 旧数据：Flutter 版的偏好在 UserDefaults 里，应用导出成 `core/legacy_shared_preferences.json` 交给内核。
- 液态玻璃：只在浮动控件层用玻璃，内容是不透明的分组卡片，设置窗口用 `.formStyle(.grouped)`；浅色、深色和中文截图已核对。
- 安装脚本 `scripts/install-macos-native.sh`：默认装最新的 `native-v*` 发布（含测试版），也可指定版本或本地 zip；核对
  SHA-256、应用 ID、架构和签名，退出并替换已装的原生版或 Flutter 版，移除隔离属性后打开。随 `native-v7.0.0-beta.1` 发布。
- CI 的检查矩阵（只下载产物、不编译）在 macOS 26.x arm64、macOS 14.8 arm64、macOS 15.7 Intel 上都通过：
  - 安装脚本覆盖假的 Flutter 版（正在运行的进程和 `Po0ClashCore`），旧订阅和加白 token 被导入；通过模拟的 releases API
    再装两次（不带版本 / 带版本），跳过草稿和 Flutter 发布、校验 digest、重启应用；
  - 真实流程（`po0-e2e`）：本地 shadowsocks 节点和订阅，系统代理 → 虚拟网卡（sudo 装 setuid 内核，命令与应用相同）→
    系统代理，三次请求都确认经过节点；
  - 普通启动不自动连接、SIGTERM 后正常关闭；菜单窗口开两次至少刷新两次；macos-26 上另有截图（含模拟开机自启的重连）。

没有验证：开机自启在真机上的触发（CI 用启动参数模拟）、管理员授权弹窗本身（CI 用 sudo 代替）、macOS 13（GitHub 已不提供
这个镜像）、Flutter 版真实运行时被安装脚本退出（CI 用假进程，真机上第一次给 po0-clash 发 Apple 事件可能要求用户同意，
超时后脚本改发 SIGTERM，这时 Flutter 版来不及清除系统代理）。

下一步：在真机上用 `native-v7.0.0-beta.1` 的安装命令覆盖 Flutter 版，试管理员授权、开机自启和系统代理的清理。

## Windows

已完成（构建机 + CI 验证）：

- Tauri 2 + Svelte，五个页面覆盖全部功能，中英文跟随系统；托盘菜单与三种状态图标，关窗隐藏到托盘，单实例，
  requireAdministrator。
- 开机自启用 XML 创建的计划任务 `po0-clash`（登录时以最高权限运行）；每 5 秒检查到 po0 接口的路由，变化时通知内核。
- `apps/windows/scripts/cross-build.sh` 在 Linux 上交叉编出 NSIS 安装包（带 clang-cl、托盘库占位和 `RestartManager.nsh`
  的绕路）。
- 在 windows-latest 上：内核测试通过，静默安装后应用以管理员身份运行 10 秒，内核建好了数据目录，界面接上真实内核并读到出口 IP。
- 液态玻璃：Mica 窗口背景，玻璃只用在底部胶囊标签栏、连接按钮、分段控件和提示条上，内容是不透明的分组列表。

已知问题：

- 引擎冒烟测试（`scripts/smoke.mjs`）需要 WebView2 的调试端口，以管理员身份运行时端口没打开，最后两次 CI 都卡在这里。
- 安装目录 `C:\Program Files\po0-clash`、程序名和开始菜单快捷方式与 Flutter 版（Inno Setup）相同，两者不能并存；替换方式待定
  （安装钩子里先卸载 Inno 版本，或测试版换目录和名字）。
- 改版后的玻璃效果还没在 Windows 上看过；没做 Acrylic 中间档（Win10 上拖动卡顿），Mica 不可用时用纯色。
- 版本号是占位的 0.1.0；还没有自签名。

下一步：在东京的 Windows 测试虚拟机里装包并跑冒烟测试（调试端口问题在虚拟机里直接排查）；看玻璃效果和深色模式；
定下替换 Flutter 版的安装方式；加自签名。

## Android

已完成（NL 上的 API 35 与 API 30 模拟器验证，已合入 `native`）：

- `mihomo/android`：Go c-shared 库，C 接口为 `po0_mihomo_start/stop/free`；start 等控制器可连才返回，stop 关掉全部入口和 TUN。
  必须带 `cmfa` 编译标签（否则 TUN 要读只有 root 能读的 `packages.xml`），库在 `init()` 里恢复 `/configs` 接口供内核热重载。
- Gradle 一条 `./gradlew assembleRelease` 编出 mihomo、内核和绑定；compileSdk 37、targetSdk 36，Compose BOM 2026.09.00、
  Haze 2.0.1。同一把签名 key，按 ABI 分包，三个分包的 versionCode 都大于 Flutter 6.4.4 对应的分包；版本名暂为 7.0.0-alpha1，
  正式版本号由维护者定。
- 模拟器上走通：VPN 路由（排除 po0 地址）与应用自身绕过 VPN、流量走节点、切节点 / 模式 / 测速、三轮断开重连无残留 fd、
  启动失败与重新连接、快捷设置磁贴（真实点击）、导出诊断、加白请求与结果跨进程保留、进程重建后按 `wasConnected()` 自动连回。
- 从 Flutter 6.4.4 覆盖升级：导入 2 条订阅（当前订阅对应正确）和 2 条加白条目，缺内容的订阅在连接时先下载，重启后不重复导入。
- API 30 上手动拆分路由：tun0 上 33 条路由，po0 地址走物理网卡，相邻地址仍走 VPN。
- 网络变化只监听物理网络（排除自己的 VPN）并去抖 1 秒；VPN 服务指令按 start id 只执行最新的一条。
- 液态玻璃：#F2F2F7 / 黑色底，不透明分组卡片，系统蓝，Haze 毛玻璃顶栏、悬浮连接胶囊、分段控件、底部弹层与操作单；
  浅色、深色、中英文都核对过。API 31 以下没有模糊，玻璃底色用约 93% 的近不透明色（与苹果「降低透明度」一致），
  半透明会让弹层透出下面的文字。

没有验证：真机 arm64、always-on VPN。

已知问题：`cmfa` 标签下订阅里写 `system` 的 DNS 解析不了；同时连着 Wi-Fi 和移动数据时，移动数据的变化也会触发一轮加白请求。

下一步：在 arm64 真机上装 `app-arm64-v8a-release.apk` 走一遍；发版前由维护者定版本号。
