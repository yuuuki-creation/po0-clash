# Rust 应用后端迁移方案

状态：提议（[ADR 0017](../adr/0017-rust-app-backend.md)）。本文是分阶段的执行计划，文件与行数按 v6.4.4 统计；
每个阶段开工前按当时的代码复核一遍。

## 范围

迁到 Rust 的是 Dart 里不属于界面的应用逻辑：加白的请求与调度、运行配置生成、订阅下载、桌面 Core 进程管理。

不迁：

- Flutter 页面、Riverpod 界面状态、持久化（drift 数据库与 preferences）。Rust 不读写它们，只接收参数。
- mihomo 与 `core/*.go`，包括分享链接转换 `convertShareLinks`。
- Android 的 VpnService、`ServiceState` 意图仲裁与进程内 cgo 内核。

迁移期间继续有效的约束：

- [ADR 0001](../adr/0001-direct-routing-for-po0-api.md) 的三层直连，以及 [ADR 0012](../adr/0012-direct-listener-and-ggy.md)
  的 `po0-direct` 入口与每次会话的凭据；只有 po0 自己的地址可以回退到普通直连。
- po0 按 `pollSeconds` 只读查询、缺失才加白（[ADR 0004](../adr/0004-per-second-read-only-polling.md)、
  [0005](../adr/0005-token-list-and-poll-interval.md)）；ggy 固定 11 秒，每次 GET 都会写入；
  总开关变化只经 `WhitelistCoordinator` 重载一次 profile（[ADR 0014](../adr/0014-unified-whitelist.md)）。
- 桌面端虚拟网卡与系统代理二选一（[ADR 0011](../adr/0011-exclusive-desktop-route.md)）。
- token 是凭据：日志与错误里最多出现 `Po0Token.label`。
- 启动、停止、重启保持最新意图优先，桌面生命周期结果区分 applied、coalesced、superseded（见 AGENTS.md）。

## 现状

| 模块 | 位置 | 逻辑行数 | 现有测试 |
|---|---|---|---|
| po0 / ggy 加白 | `lib/common/po0_firewall.dart`、`lib/providers/po0_firewall.dart` | 557 + 487 | `test/common/po0_firewall_test.dart`（503）、`test/providers/po0_firewall_test.dart`（729） |
| 运行配置生成 | `lib/common/task.dart` 的 `_makeRealProfileTask`、`lib/providers/actions/setup.dart` 的 `getProfile` | 约 205 + 75 | `test/common/task_test.dart`（617）、`test/providers/setup_action_test.dart`（917）的相关部分 |
| 订阅下载 | `lib/models/profile.dart` 的 `update` / `saveFile`、`lib/common/request.dart` | 约 35 + 170 | `test/models/profile_test.dart`（120） |
| 桌面 Core 进程管理 | `lib/core/desktop/` 9 个文件、`lib/core/service.dart` | 2,541 + 114 | `test/core/desktop/`（约 2,700） |
| 已有 Rust | `plugins/rust_api/rust`（IPC 服务、快捷键、脚本）、`services/helper` | 约 3,000 + 2,100 | `cargo test`（`windows-validation.yaml`） |

## 目标结构

```text
Flutter 界面（Dart）：页面、界面状态、持久化
        │  flutter_rust_bridge（plugins/rust_api）
        ▼
Rust 应用后端：whitelist / profile / supervisor（supervisor 仅桌面）
        │  桌面：现有 ipc 模块        Android：不变（MethodChannel → Kotlin Service → cgo 内核）
        ▼
mihomo 内核（Go）：不变
```

做法约定：

1. `api/` 只放 flutter_rust_bridge 的薄封装，逻辑放在不依赖 frb 类型的模块里，能直接 `cargo test`。
2. 每个 Rust 入口在 Dart 侧都有可注入的函数类型或接口，参照 `lib/core/desktop/transport.dart` 的 `IpcServerStarter`，
   这样 `flutter test`（`verify.sh` 跳过原生构建）可以继续用假实现。
3. 先迁纯函数，再迁带网络 IO 的部分，最后迁持有计时器和进程的部分。
4. 切换以提交为单位，不加运行时开关；出问题回滚该提交并发修复版。
5. 迁之前先固定行为：把对应的 Dart 测试用例移植成 Rust 测试；纯函数用 Dart 实现生成的 golden 文件对拍。
6. Rust 日志经事件流汇入应用日志页，错误文本先脱敏。

## 阶段 0：基础设施

- 在 `plugins/rust_api/rust` 内新增 `whitelist/`、`profile/`、`supervisor/` 模块。等体量变大、或需要与 `services/helper`
  共享协议类型时，再拆成 workspace 成员 crate。
- 选定 HTTP、TLS 与异步栈：TLS 用 rustls，根证书用自带 ISRG Root X1 的 webpki-roots，或沿用 `po0SecurityContext`
  显式加入 ISRG Root X1 的做法；HTTP 客户端在 `ureq`（同步、体积小）与 `reqwest`（tokio）之间按体积测量结果选，
  必须支持带 Basic 认证的 HTTP 代理（`po0-direct`）。
- 日志桥（Rust `log` → 事件流 → `commonPrint`）与带错误码的结构化错误。
- `scripts/vps/verify.sh` 增加 `cargo fmt --check`、`cargo clippy --all-targets -- -D warnings` 与 `cargo test --locked`，
  执行前把 `/opt/toolchains/rust-1.95.0/bin` 加入 `PATH`。`windows-validation.yaml` 已经在 Windows 上跑 rust_api 的测试，保持不变。
- 记录基线：三端安装包与 Android 各 ABI `.so` 的体积，以及 `tool/measure_resident_memory.py` 测得的常驻内存。

退出条件：一个空 API（例如 `backend_info()`）在 Windows、macOS、Android 的发版构建里都能调用；`rust-toolchain.toml`
列出的 9 个 target 都能编译；基线数字补进本文。

## 阶段 1：po0 / ggy 加白（试点）

加白是本分支自有代码，不合并上游，行为由 ADR 写清，测试也最全，所以用它验证工具链、接口方式与测试方式。

**1a 纯函数。** `parsePo0Tokens`、`isPo0Token`、`isGgyLink`、`po0TokensOf` / `ggyLinksOf`、`sameC24`、`excludeIpv4Route`、
`withPo0DirectListener`、`po0ListenerRoute`、`po0FindProxy`。把 `test/common/po0_firewall_test.dart` 的对应用例移植为
Rust 测试；Dart 测试改为验证注入函数的调用与结果映射。

**1b 请求。** `Po0DirectTransport` 与 `Po0FirewallClient`（po0 的 query / add / poll，ggy 的 GET）。保持 5 秒连接超时、
网络变化时 `resetConnections`、内核运行时只走 `po0-direct`。

验证：

- Rust 测试起本地 HTTPS 假服务和假代理，断言除 po0 地址外一律走代理、po0 地址只在入口不可用时直连、凭据不进日志。
- 真机：Android 跑 `android/tests/device/VpnTakeoverInstrumentation.kt`；Windows 分别在虚拟网卡与系统代理下测；macOS 测一遍。
- 加白结果里的出口 /24 必须是物理出口，不能是节点 IP（ADR 0001 的正确性目标）。

**1c 调度（试点评估后再定）。** `WhitelistScheduler` 的计时器、最长 30 秒的退避、亮灭屏、网络变化与总开关的路由过渡
（`beginRoutingTransition` / `finishRoutingTransition`）迁到 Rust，Dart 只发信号、收状态流。需要同步修改
[.agents/fork.md](../../.agents/fork.md) 中由 `Po0Firewall` / `GgyFirewall` 持有调度的规则。用可控时钟把
`test/providers/po0_firewall_test.dart` 的调度用例移植到 Rust。

试点评估（维护者决定是否进入阶段 2）：

- 三端各发一版，连续一周没有加白回归。
- 体积与内存增量在预算内。建议预算为 Android 每个 ABI 不超过 3 MB、常驻内存不超过 5 MB，由维护者确认。
- 对比迁移前后的代码量、测试耗时与改动难度。

## 阶段 2：配置生成与订阅更新

**2a 运行配置生成。** `_makeRealProfileTask` 与 `getProfile` 里拼装运行配置的部分：端口与认证、DNS 覆写、TUN、
规则与分组覆写、provider 路径收拢、po0 直连规则与 `route-exclude-address`、`po0-direct` 入口。改成 Rust 纯函数：
输入原始配置（JSON）与补丁参数，输出 YAML 与 md5。

验证：切换前用现有 Dart 实现在合成配置语料（不含真实订阅与凭据）上生成 golden 文件，Rust 测试按结构比较。
输出字节变化只会让 `lastConfigMd5` 失效一次，可以接受。

**2b 覆写脚本并入流水线。** `handleEvaluate` 已经在 Rust（rquickjs）里执行，改为在 Rust 内串起
「原始配置 → 脚本 → 补丁」，省掉整份配置在 Dart 与 Rust 之间来回传。

**2c 订阅下载。** `Profile.update`：UA、重定向、`content-disposition` 文件名、`subscription-userinfo`、写临时文件、
内核 `validateConfig`、原子替换。代理选择与现在的 `request` 保持一致。Rust 测试用本地 HTTP 服务覆盖响应头解析、重定向、
超时，以及校验失败时不覆盖旧文件。

同步成本：这三个文件都在合并上游前端的范围内，迁走后在 [upstream-sync.md](upstream-sync.md) 记下「上游改动需手工移植到 Rust」。

## 阶段 3：桌面 Core 进程管理

前置：新 ADR，并改写 AGENTS.md 的所有权规则与 [.agents/architecture.md](../../.agents/architecture.md)。

范围：`lib/core/desktop/` 与 `lib/core/service.dart` 迁成 Rust `supervisor`，涵盖：

- 启动、停止、重启（applied / coalesced / superseded）
- RPC 的 id 匹配与超时延长规则
- 意外断开与崩溃事件
- Windows 虚拟网卡走的 helper 路径
- 启动错误码归因（225 / 226 / 577 / 1260）

IPC 服务本来就在 Rust 的 `ipc` 模块里，这一步把它的使用方也搬过去。Dart 侧 `CoreController` /
`CoreHandlerInterface` 的接口不变，界面与 provider 不用改。

同时补上持久化日志：Core 的 stderr 与生命周期失败写入数据目录下的滚动日志文件。现在 helper 只把日志留在内存里，
`DirectCoreLauncher` 只转进应用日志页，Core 断开后很难复盘。这一项不依赖迁移，也可以先在 Dart 里单独做。

验证：

- 先把 `test/core/desktop/` 约 2,700 行测试移植成 Rust 测试（假启动器、假传输、可控时钟），再切换。
- `windows-validation.yaml` 在 Windows 上跑这些测试。
- 手工矩阵：连续启停、强杀 Core 进程、虚拟网卡与系统代理互切、睡眠唤醒、启动过程中切换配置、Core 运行时退出应用。

Android 不在这一阶段：Android 的 Core 在 VpnService 进程内以 cgo 库运行，意图仲裁归 `ServiceState`，不变。

## 风险与对策

| 风险 | 对策 |
|---|---|
| 界面进程多一个运行时，体积和内存上涨 | 每个阶段对比阶段 0 的基线，超出预算不进入下一阶段 |
| `flutter test` 不构建原生库，Rust 回归在 Dart 测试里看不出来 | `verify.sh` 加 Rust 检查；Windows 由 `windows-validation.yaml` 覆盖；发版前跑真机矩阵 |
| Dart 覆盖率门槛为 75%，迁走测试充分的代码会拉低比例 | 每个阶段复核 `tool/check_coverage.dart` 的结果；调整门槛需维护者同意；Rust 侧可另加 `cargo llvm-cov` |
| Android 上 Rust 发出的 socket 与 Dart 一样受 VPN 路由影响 | ADR 0001 的三层直连保持不变，阶段 1 的真机测试必须通过 |
| flutter_rust_bridge 固定在 `=2.13.0`，生成代码要能重现 | 只通过代码生成更新生成文件，不手改 |
| 迁走上游文件后，合并上游前端更费事 | 阶段 2 只在试点证明值得后再做，并记录到同步文档 |

## 工作量

| 阶段 | 替换的 Dart 逻辑 | 需移植的测试 |
|---|---|---|
| 0 | 无 | 无 |
| 1 | 约 1,050 行 | 约 1,230 行 |
| 2 | 约 300 行，另有 `request.dart` 的相关部分 | `task_test.dart` 与 `setup_action_test.dart` 的相关用例 |
| 3 | 约 2,650 行 | 约 2,700 行 |
