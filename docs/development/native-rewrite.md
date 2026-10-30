# 三端原生重写

决定见 [ADR 0018](../adr/0018-native-rewrite.md)。原则只有一条：能不做的都不做。

## 结构

```text
apps/macos     SwiftUI
apps/windows   Tauri 2：Web 界面 + Rust 外壳
apps/android   Kotlin + Jetpack Compose，含 VpnService 与快捷设置磁贴
crates/core    共享 Rust 内核
crates/ffi     UniFFI 绑定（Swift / Kotlin）
mihomo/        原版 mihomo 子模块（固定版本）与 Android 的薄 JNI 层
```

Flutter 版的目录（`lib`、`android`、`macos`、`windows`、`core`、`plugins`、`services` 等）在三端都替换完成后删除。

## 共享内核

`crates/core` 只做六件事。所有状态由内核持有，设置文件只由内核读写，界面只通过内核接口操作；接口用普通 Rust 类型，
UniFFI 和 Tauri 命令只做转换：

1. **设置**：一个 JSON 文件加一个订阅目录，不用数据库。
2. **订阅**：按 URL 下载，读取流量与到期信息，定时更新。
3. **节点导入**：粘贴的分享链接存成本地文件，作为 `file` 类型的 proxy-provider 交给 mihomo 解析。实施前先确认 mihomo
   能直接读 V2RayN 格式的链接列表；读不了再在内核里转换。
4. **配置生成**：订阅加少量固定覆盖，包括端口、虚拟网卡或系统代理、po0 直连规则与 `po0-direct` 入口。DNS 沿用订阅里的
   设置，订阅没写时才用内置默认值。不提供规则编辑和覆写。
5. **加白**：po0 与 ggy 的请求和调度。请求部分直接用 PR #26 已完成的 Rust 传输层（ureq + rustls，只走 IPv4）。
6. **引擎控制**：桌面端启动、停止、重载 mihomo 进程；通过 external-controller 读策略组、切换节点、测延迟、读流量；
   mihomo 的 stderr 和内核自身的错误写入滚动日志文件。引擎意外退出时只报错并写日志，界面给一个「重新连接」按钮，
   不自动重启。

## 引擎运行方式

| 平台 | 运行方式 | external-controller |
|---|---|---|
| macOS | 界面和内核在同一个进程；mihomo 是子进程，二进制设 setuid root，首次使用时授权一次，以支持虚拟网卡 | Unix 套接字 |
| Windows | 应用以管理员身份运行，两种模式都由应用直接启动 mihomo | 命名管道 |
| Android | 界面、内核和 VpnService 在同一个进程；VpnService 建立 TUN，mihomo 编成 Go 库在进程内运行，外面只包一层很薄的 JNI | 应用私有目录下的 Unix 套接字 |

- 桌面端没有单独的后台服务，菜单栏和托盘应用本身就常驻。Flutter 版的 Rust helper 服务不再需要。
- Windows 每次启动都会弹出 UAC 提示；开机自启用计划任务的「使用最高权限运行」，登录时不弹窗。
- Android 用单进程换最简单的结构，代价是界面进程崩溃时 VPN 也会断开。

## 功能范围

三端一致，只保留：

- 连接开关与状态（当前节点、出口 IP）。
- 订阅：添加、更新、删除、切换，显示流量与到期时间。
- 用分享链接导入节点。
- 策略组与节点选择、延迟测试。
- 模式：规则、全局、直连。
- 桌面端在虚拟网卡与系统代理之间二选一；Android 使用 VPN。
- 加白：po0 token 与 ggy 链接列表、总开关、每条最近一次的结果。po0 固定每 5 秒轮询一次，ggy 固定 11 秒。
- 开机自启（桌面）、快捷设置磁贴（Android）。
- 导出诊断日志。
- 界面语言：简体中文和英文。

不做（确有需要时再单独提）：

- 流量图表、连接与请求列表、实时日志页。
- 规则编辑、标准与脚本覆写、DNS 和高级网络设置、端口设置、局域网共享、对外开放的 external-controller。
- WebDAV 备份、IP 质量检测、网站探测、全局快捷键、主题与配色设置（一律跟随系统）。
- Android 分应用代理。
- 加白轮询间隔的调节。

## 界面

每端都有主界面，结构接近 FlClash（ADR 0019）：导航依次为仪表盘、代理、订阅、加白、设置；仪表盘是卡片网格加右下角的
浮动启动按钮，代理页是可展开的策略组卡片和节点卡片网格。三端都按苹果液态玻璃（Liquid Glass）的规范来做，而且要克制：
玻璃只用在浮动的控件层（导航栏、分段控件、连接按钮、工具栏、弹窗），内容区是不透明的分组列表；背景用中性色，
强调色用系统蓝，状态用苹果系统色，图标单色；不加彩色背景、渐变和发光。

- **macOS**：主窗口（侧边栏导航）加菜单栏快捷窗口（`MenuBarExtra`）。用 macOS 26 SDK 编译，系统控件和侧边栏自带液态玻璃，
  只在浮动控件上另加 `glassEffect`；更早的系统用系统默认外观。
- **Windows**：托盘加主窗口。Web 界面用轻量框架（倾向 Svelte），不引入组件库。窗口背景用 Mica（退回 Acrylic），浮动控件
  用 `backdrop-filter` 模仿玻璃。
- **Android**：底部导航的主界面，页面与桌面端相同。以 Material 3 组件为底，按上面的规范改样式，不用动态取色；API 31 起浮动控件做背景模糊，
  更早的系统只用半透明底色。

## 不变的约束

- 应用 ID `io.github.yuuukicreation.po0clash`、已提交的 Android 签名密钥和递增的 versionCode 都保留，老用户可以覆盖升级。
- 首次启动时从 Flutter 版的数据目录只导入订阅和加白 token，其它设置不迁移。drift 数据库就是 SQLite，内核可以直接读。
- 加白请求走物理出口的三层保证（ADR 0001、0012）：直连规则与 `route-exclude-address`、Android VPN 路由拆分、内核运行时走
  `po0-direct` 入口。
- 匿名：提交与发布都用 yuuuki-creation，不申请实名开发者账号。

进度记录在 [native-progress.md](native-progress.md)。

## 顺序

1. 共享内核，加上原版 mihomo 的接入：桌面进程管理和 external-controller 客户端。
2. macOS 原生版。
3. Android 原生版。
4. Windows 原生版。

每一端可用后先作为测试版与 Flutter 版并行发布，确认没有问题再替换。

## 构建与测试

不在本机编译。三台构建机各管一端，工具链由 `/etc/profile.d/po0-native.sh` 加载，每个任务用自己的 `/srv/build/po0-<任务名>` 目录：

| 机器 | 用途 |
|---|---|
| `contabo-fr` | Rust 内核：`cargo fmt`、`clippy`、`test`，以及真实 mihomo 的集成测试 |
| `nobrand-tokyo-perf` | Windows：cargo-xwin 交叉编译与 NSIS 打包；KVM 上的 Windows 测试虚拟机做安装与运行测试 |
| `hostdzire-nl` | Android：cargo-ndk、Gradle 构建，KVM 模拟器（AVD `po0-api35`）上测试 |

- Android 和 Windows 的编译与测试都在构建机上做，不依赖 GitHub Actions；Actions 只负责 macOS，因为 macOS 只能在苹果硬件上
  编译。Windows 的 Actions 工作流只保留手动触发，作为发版前的补充检查。
- 内核的集成测试默认跳过，需要一个 mihomo 可执行文件：
  `MIHOMO_BIN=<mihomo> cargo test -p po0-core -- --ignored engine`。它在本地起一个 shadowsocks 入口当节点，覆盖启动、
  策略组、延迟测试、出口 IP、模式切换、热重载、选节点、崩溃检测与重启。
- UniFFI 绑定从未裁剪的宿主库生成（发版库会去掉元数据）：`cargo build -p po0-ffi`，再运行
  `cargo run -p po0-ffi --features cli --bin uniffi-bindgen -- generate --library target/debug/libpo0_ffi.<so|dylib> --language <kotlin|swift> --out-dir <目录>`。
