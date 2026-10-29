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

已完成（CI 验证，macos-26、Xcode 26.6、SDK 26）：

- SwiftPM 包，最低 macOS 13，不显示程序坞图标，中英文跟随系统，用真实内核绑定。
- 菜单栏窗口：连接开关与状态、当前节点、出口 IP、速率、模式、系统代理 / 虚拟网卡、切换订阅、选节点与测延迟、加白开关和摘要、
  失败时的「重新连接」。设置窗口三个标签：通用（开机自启、导出诊断、版本）、订阅、加白。
- 虚拟网卡：首次使用时用一次管理员授权把 mihomo 装到 `/Library/Application Support/io.github.yuuukicreation.po0clash/mihomo`
  （root:wheel、4755，SHA-256 与包内一致才复用），取消授权就退回系统代理。
- 旧数据：Flutter 版的偏好在 UserDefaults 里，应用导出成 `core/legacy_shared_preferences.json` 交给内核。
- 液态玻璃：只在浮动控件层用玻璃，内容是不透明的分组卡片，设置窗口用 `.formStyle(.grouped)`。
- CI：macOS 上的内核测试与真实引擎测试、打包与 ad-hoc 签名、启动 10 秒、SIGTERM 后正常关闭、截图上传。

没有验证：真机上的整套流程（订阅、连接、切节点、加白、导出、开机自启），虚拟网卡授权与 setuid 运行，深色模式，
有数据时的界面，通用包（`ARCHS="arm64 x86_64"`），macOS 13/14 上菜单窗口的刷新时机。

下一步：在真机上装 CI 产物 `po0-clash-macos.zip` 走一遍上面的流程；验证虚拟网卡和切回系统代理；检查深色模式；打通用包。

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

已完成（NL 模拟器上验证，改版前的版本）：

- `mihomo/android`：Go c-shared 库，C 接口为 `po0_mihomo_start/stop/free`；start 等控制器可连才返回，stop 关掉全部入口和 TUN。
  必须带 `cmfa` 编译标签（否则 TUN 要读只有 root 能读的 `packages.xml`），库在 `init()` 里恢复 `/configs` 接口供内核热重载。
- Gradle（AGP 9.5.0、Kotlin 2.4.21）一条 `./gradlew assembleRelease` 编出 mihomo、内核和绑定；同一把签名 key，按 ABI 分包，
  versionCode 大于 Flutter 6.4.4。受 compileSdk 36 限制固定了 Compose BOM 2026.06.01 和 Haze 1.7.1。
- 模拟器上走通：订阅与用量、分享链接导入、VPN 路由（排除 po0 地址）与应用自身绕过 VPN、流量走节点、切节点 / 模式 / 测速、
  三次断开重连无残留 fd、启动失败与重新连接、快捷设置磁贴、网络切换、加白请求链路、导出诊断、中英文。
- 液态玻璃：浅色中文界面已在模拟器上看过（#F2F2F7 底色、白色分组卡片、Haze 毛玻璃顶栏和悬浮连接胶囊、玻璃分段控件和底部弹层）。

没有验证：改版后的完整流程、深色模式、改版后的英文界面、真机 arm64、API 26–32 的手动路由拆分（只有单元测试）、
从 Flutter 版覆盖升级与旧数据导入、always-on VPN。

已知问题：`cmfa` 标签下订阅里写 `system` 的 DNS 解析不了；TUN fd 交给 mihomo 后由它关闭，内核在启动前失败时由 Kotlin 兜底关闭。

下一步：在 NL 上用 `/srv/build/po0-native-android/.tools` 里的脚本把改版后的版本完整重测，补深色和英文；编三个 ABI 上真机测；
测覆盖升级；整理提交历史后合入 `native`。
