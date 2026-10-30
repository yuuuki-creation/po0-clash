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

`native-windows`（3c978d8）尚未合入。构建已移到东京（`apps/windows/scripts/cross-build.sh`，约 5 分钟），东京的 Windows 11 测试虚拟机
（Docker 容器 `po0-winvm`，从东京 `ssh -p 2222` 进入，测试脚本在 `/srv/build/po0-native-windows/vm`）里验证过：系统代理和虚拟网卡两种
模式下流量都经过节点、断开后系统代理与网卡清理干净；从 Flutter 6.4.4 覆盖升级（静默卸载旧版，保留数据并导入）；开机自启后按
`was_connected()` 重连；液态玻璃界面的中英文和深浅色截图。管理员权限下 WebView2 的调试端口只认 HKLM 策略。

待处理：内核的 TUN 在 Windows 上要用 gvisor 栈（`mixed` 下 TCP 全部超时并弹防火墙提示，测试时在本地临时改过，未提交）；
改完后用提交的版本在虚拟机里重跑冒烟测试；签名；托盘菜单截图。

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
- 主界面按 [native-design.md](native-design.md) 重做：34 号大标题加 15 号副标题，右上角 44 高的玻璃按钮组；悬浮标签栏
  （距底 30、左右 20、高 62，细线条图标，选中项强调色加浅色选中块）；标签栏上方是底部状态条（状态圆点、已连接 / 未连接、
  「时长 · 节点」或失败原因，右边实心圆形启停按钮），取代原来的浮动按钮；内容区底部留出两条栏的高度。颜色、字号、圆角 22
  的白底卡片都照规范的表，图标是规范设计稿里的线性图标（`LineIcons.kt`）。API 31 以下玻璃用近不透明的底色。
- 仪表盘依次是网络速度（`traffic_history` 画最近 60 秒，下载强调色线加淡色面积，上传灰线）、出站模式、当前节点（点进代理），
  流量与连接并排，内存与出口 IP 并排，订阅、自动加白；右上角测当前节点所在组。代理页是策略组卡片加两列节点块，选中节点强调色
  描边加对勾，延迟 <600ms 绿、更高橙、超时红；右上角排序（默认 / 延迟 / 名称）、定位到当前节点、全部测速；点节点延迟单独测速。
  工具页首组是「活动」（显示连接数），然后配置、应用、其他三组。
- 功能对齐（[native-feature-parity.md](native-feature-parity.md)）里内核已有的项都接上了：活动页的请求 / 连接 / 日志（搜索、
  点开看连接详情、断开单个或全部、日志级别筛选与导出）；EngineOptions 的全部字段做成基础配置、网络（虚拟网卡）、DNS（覆写开关
  与完整设置）、高级（追加规则）四个表单，改动立刻显示、只把最后一次写进内核；资源页有 Geo 文件信息与更新、加载方式、
  自动更新与间隔、下载地址，以及代理集、规则集的信息、用量与更新；配置页的文件导入、编辑、导出、预览、排序上一轮已做。
- Android 独有的：访问控制（仅代理 / 不代理所选应用，搜索、显示系统应用、只看联网应用、已选在前、全选、清空、剪贴板导入导出，
  重新连接后生效）；按需连接（排除的 Wi-Fi，可一键加入当前 Wi-Fi；连到时断开、离开后自动重连；定位、始终定位、电池优化的
  状态与入口）；`<applicationId>.action.START` / `STOP` / `TOGGLE` 外部 intent（与 Flutter 版同名，透明 Activity 处理）；
  TV 的 Leanback 入口（横幅沿用 Flutter 版的 `ic_banner`）；通知栏停止按钮开关、最近任务中隐藏；网络页的允许应用绕过、
  VPN 内系统代理、VPN IPv6。
- 应用设置都读写内核的 `app_settings()`：外观（跟随系统 / 浅 / 深、主题色预设与自定义色、纯黑、文字大小）、语言（跟随系统 /
  简体中文 / English，存 BCP 47 标签，API 33 起用系统的分应用语言，更早的版本在 Activity 上换 Configuration）、应用页的开关
  （自动连接、最近任务中隐藏、通知栏停止按钮、页面切换动画、标签栏文字、日志捕获、切换节点后断开、只统计代理流量、校验证书、
  自动检查更新、崩溃保护）、代理页显示方式（标签式 / 列表式，默认标签式；排序、疏密、节点卡片样式）、仪表盘卡片的顺序与显隐
  （右上角「编辑仪表盘」）、分应用代理和排除的 Wi-Fi。关掉日志捕获时活动页不显示日志。只有允许绕过、VPN 内系统代理、VPN IPv6
  三项内核没有字段，仍存在 Android 的 SharedPreferences。仪表盘加了「内网 IP」（`intranet_ip()`，网络变化时重读）和
  「网络接管」（VPN 开关）。模拟器上验证过：主题色即时生效、语言切换、排除 Wi-Fi 写进 settings.json 并断开 / 重连。
- 策略组图标（配置里的 `icon`：图片地址、内联 SVG 或 base64）显示在标签和组卡片上，按 `group_icon_style` 显示为图标加名称、
  仅图标或不显示，读不出来时就不显示图标。SVG 用 AndroidSVG 解码，下载的图标缓存在 cacheDir；应用自己的 Java 网络请求只有这一处，
  为了和 Flutter 版一样能读 http 图标，打开了 `usesCleartextTraffic`。
- 工具 → 备份与恢复：备份到文件 / 从文件恢复（系统文件选择器），WebDAV 地址、账号、密码、文件名，检查连接、备份到 WebDAV、
  从 WebDAV 恢复，恢复时选全部数据或仅配置，恢复策略（合并 / 覆盖）。恢复后重读应用设置、内核选项和配置。模拟器上走通：
  文件备份与恢复（恢复后改过的主题色回到备份里的值）；用 NL 上的测试 WebDAV，错误密码报「WebDAV refused the user name or
  password」，正确密码时检查、上传 `po0-clash/backup.zip`、下载恢复都成功，VPN 全程保持连接。
- 模拟器上验证过：三个外部 intent 各自生效；排除当前 Wi-Fi 后 2 秒断开、移除后 2 秒自动连回；只代理 Chrome 时 VPN 的
  UID 范围只剩 Chrome；日志级别改 Info 后写进 settings.json、日志页出现 Info 日志；未连接时更新 Geo 下载了四个文件。
  连接中更新 Geo 走 mihomo 自己的 `/configs/geo`，日志显示开始更新但两分钟内没有写出文件，没有再查。

没有验证：真机 arm64、always-on VPN。

已知问题：`cmfa` 标签下订阅里写 `system` 的 DNS 解析不了；同时连着 Wi-Fi 和移动数据时，移动数据的变化也会触发一轮加白请求。

下一步：在 arm64 真机上装 `app-arm64-v8a-release.apk` 走一遍；发版前由维护者定版本号。
