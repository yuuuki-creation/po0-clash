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

`crates/core` 只做六件事，接口用普通 Rust 类型，UniFFI 和 Tauri 命令只做转换：

1. **设置**：一个 JSON 文件加一个订阅目录，不用数据库。
2. **订阅**：按 URL 下载，读取流量与到期信息，定时更新。
3. **节点导入**：粘贴的分享链接存成本地文件，作为 `file` 类型的 proxy-provider 交给 mihomo 解析。实施前先确认 mihomo
   能直接读 V2RayN 格式的链接列表；读不了再在内核里转换。
4. **配置生成**：订阅加少量固定覆盖，包括端口、虚拟网卡或系统代理、DNS 默认值、po0 直连规则与 `po0-direct` 入口。
   不提供规则编辑和覆写。
5. **加白**：po0 与 ggy 的请求和调度。请求部分直接用 PR #26 已完成的 Rust 传输层（ureq + rustls，只走 IPv4）。
6. **引擎控制**：桌面端启动、停止、重载 mihomo 进程；通过 external-controller 读策略组、切换节点、测延迟、读流量；
   mihomo 的 stderr 和内核自身的错误写入滚动日志文件。

## 引擎运行方式

| 平台 | 运行方式 | external-controller |
|---|---|---|
| macOS | mihomo 二进制设 setuid root，沿用现在的授权方式，以支持虚拟网卡 | Unix 套接字 |
| Windows | 虚拟网卡模式由 Rust helper 服务以 SYSTEM 启动；系统代理模式由应用直接启动 | 命名管道 |
| Android | VpnService 建立 TUN，mihomo 以库的形式在同一进程运行 | 应用私有目录下的 Unix 套接字 |

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

- 仪表盘、流量图表、连接与请求列表、实时日志页。
- 规则编辑、标准与脚本覆写、DNS 和高级网络设置、端口设置、局域网共享、对外开放的 external-controller。
- WebDAV 备份、IP 质量检测、网站探测、全局快捷键、主题与配色设置（一律跟随系统）。
- Android 分应用代理。
- 加白轮询间隔的调节。

## 界面

各端从零设计，不参照 Flutter 版的页面结构和样式：

- **macOS**：以菜单栏为主（`MenuBarExtra`），另有一个设置窗口。用系统原生控件；macOS 26 上用液态玻璃，更早的系统用系统默认外观。
- **Windows**：托盘加一个小窗口。Web 界面用轻量框架（倾向 Svelte），不引入组件库。
- **Android**：一个主屏加一个设置页，Material 3。

## 不变的约束

- 应用 ID `io.github.yuuukicreation.po0clash`、已提交的 Android 签名密钥和递增的 versionCode 都保留，老用户可以覆盖升级。
- 首次启动时从 Flutter 版的数据目录导入订阅和加白 token。drift 数据库就是 SQLite，内核可以直接读。
- 加白请求走物理出口的三层保证（ADR 0001、0012）：直连规则与 `route-exclude-address`、Android VPN 路由拆分、内核运行时走
  `po0-direct` 入口。
- 匿名：提交与发布都用 yuuuki-creation，不申请实名开发者账号。

## 顺序

1. 共享内核，加上原版 mihomo 的接入：桌面进程管理和 external-controller 客户端。
2. macOS 原生版。
3. Android 原生版。
4. Windows 原生版。

每一端可用后先作为测试版与 Flutter 版并行发布，确认没有问题再替换。

## 构建与测试

不在本机编译。

- Rust 内核：在构建机 NL 上跑 `cargo fmt`、`clippy`、`test`，再用真实的 mihomo 进程做集成测试。
- Android：在 NL 上用 Gradle 构建，并在模拟器上测试。
- macOS 与 Windows：由 GitHub Actions 的对应 runner 构建和测试。
