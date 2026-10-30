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

7.0.0-beta.1 之后待修（Windows 测试中发现，影响三端）：全局模式下 GLOBAL 组默认选 DIRECT，应在没有保存的选择时选第一个策略组；
刚连上时策略组还没加载完（为空、当前节点显示 COMPATIBLE、出口 IP 查不到），应等 provider 就绪再刷新；导入节点没有类型，
测速结果不保留。

仍待处理：Windows 下的引擎路径（命名管道、Job Object、系统代理、名为 `po0-clash` 的 TUN 网卡）只靠应用在测试虚拟机里的
冒烟测试覆盖，内核的集成测试目前只在 Unix 上跑。

## macOS

已完成（CI 验证，macos-26、Xcode 26.6、SDK 26，通用包 arm64 + x86_64）：

- SwiftPM 包，最低 macOS 13，不显示程序坞图标，中英文跟随系统，用真实内核绑定。
- 菜单栏窗口：连接开关与状态、当前节点、出口 IP、速率、模式、系统代理 / 虚拟网卡、切换订阅、选节点与测延迟、加白开关和摘要、
  失败时的「重新连接」。设置窗口三个标签：通用（开机自启、导出诊断、版本）、订阅、加白。
- 虚拟网卡：首次使用时用一次管理员授权把 mihomo 装到 `/Library/Application Support/io.github.yuuukicreation.po0clash/mihomo`
  （root:wheel、4755，SHA-256 与包内一致才复用），取消授权就退回系统代理。
- 开机自启后，如果用户上次是连接状态（内核的 `wasConnected()`），自动重新连接；手动打开不会自动连接。
- 菜单窗口在 macOS 13/14 上也会每次打开时刷新（除了 onAppear 还跟踪窗口的遮挡状态）。
- 旧数据：Flutter 版的偏好在 UserDefaults 里，应用导出成 `core/legacy_shared_preferences.json` 交给内核。
- 液态玻璃：只在浮动控件层用玻璃，内容是不透明的分组卡片，设置窗口用 `.formStyle(.grouped)`；浅色、深色和中文截图已核对。
- CI 的真实流程（`scripts/e2e.sh`）：本地 shadowsocks 节点和订阅，添加订阅、导入分享链接，系统代理 → 虚拟网卡（sudo 装
  setuid 内核，路径和命令与应用相同）→ 系统代理，三次请求都确认经过节点；root 文件归属问题在 `mihomo-root` 改动后不再出现。

没有验证：开机自启在真机上的触发（CI 用启动参数模拟登录启动）、管理员授权弹窗本身（CI 用 sudo 代替）、macOS 13/14
上的实际表现（runner 只有 macOS 26）、Intel 机器上运行通用包。

下一步：在真机上装 CI 产物 `po0-clash-macos.zip`，试一次管理员授权和开机自启；有条件时在 macOS 13/14 上看一眼菜单窗口。

## Windows

`native-windows` 尚未合入。构建已移到东京（`apps/windows/scripts/cross-build.sh`，约 5 分钟），东京的 Windows 11 测试虚拟机
（Docker 容器 `po0-winvm`，从东京 `ssh -p 2222` 进入，测试脚本在 `/srv/build/po0-native-windows/vm`）里验证过：系统代理和虚拟网卡两种
模式下流量都经过节点、断开后系统代理与网卡清理干净；从 Flutter 6.4.4 覆盖升级（静默卸载旧版，保留数据并导入）；开机自启后按
`was_connected()` 重连；液态玻璃界面的中英文和深浅色截图。管理员权限下 WebView2 的调试端口只认 HKLM 策略。

主界面（ADR 0019、0020）：托盘加一个仿「访达」的无边框主窗口：悬浮玻璃侧边栏（仪表盘、代理、配置、加白、活动、工具），
自绘的统一工具栏（标题和副标题、玻璃胶囊里的图标按钮、窗口按钮）和滚动边缘效果；仪表盘是卡片网格加浮动启动按钮，代理页是
策略组标题加节点卡片网格，配置、加白、工具是分组表单，工具页里还没有接上的入口显示「即将推出」。接上内核 cb04049 的接口后，
仪表盘多了速率曲线、流量统计和内存卡片，代理页能单测一个节点，活动页显示请求、连接（可逐条或全部断开）和日志。在测试虚拟机里
装包后通过界面走通：系统代理下连接且流量经过本地测试节点、导入分享链接（结果用对话框提示）、切节点、单组与全部测速、
规则 / 全局 / 直连、运行中切到虚拟网卡再切回、自动加白开关与立即检查、工具里的开机自启与子页面、收起侧边栏、断开后系统代理
清除；窗口拖动、拖边缘缩放、最大化与还原、最小化、关闭后再次启动唤回。活动页的请求、连接、清空与断开，单节点测速，以及用内核默认的 gVisor 栈在虚拟网卡下
流量经过节点且不再弹防火墙提示，也在虚拟机里确认过。六个页面的中英文、浅色与深色截图和一张滚动到工具栏下的截图已核对（构建机 `/srv/build/po0-windows-main/vm/shots`）。内核在一次测速之后通知的策略组不带延迟，
界面暂时保留最近一次测速结果。

待处理：工具页各入口接上内核的 `engine_options()` 等接口；用 `scripts/smoke.mjs` 重跑一遍冒烟测试；签名；托盘菜单截图。

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
