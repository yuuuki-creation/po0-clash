# 0017. 应用后端分阶段迁到 Rust，内核与界面不变

- 状态：提议
- 日期：2026-10-29

## 背景

维护者希望用 Rust 重写 po0-clash 的后端。现在的分层是：Flutter 界面与应用逻辑（Dart）、mihomo 代理内核（Go，
`core/Clash.Meta` 与 `core/*.go` 包装层）、Android VpnService（Kotlin），以及已有的两块 Rust：`plugins/rust_api`
（flutter_rust_bridge，承担桌面端 Core IPC 服务、全局快捷键和覆写脚本引擎）与 `services/helper`（Windows / Linux 特权 helper）。

评估过把 mihomo 换成 Rust 内核。目前最接近可用的是 clash-rs（v0.10.10，用户手册仍标为预发布）：

- 维护者自己的订阅有 13 个节点，其中 3 个 mieru 不在 clash-rs 的出站协议列表里；7 个 VLESS 使用 Reality +
  xtls-rprx-vision，文档只列出 Reality；14 个规则集全是 mihomo 专有的 mrs 格式，文档没有提到。
- clash-rs 文档只列出 Linux、macOS、Windows 与 iOS，没有 Android。
- 自行用 Rust 重写 mihomo 约 13 万行 Go，还要长期追新协议，也违背 [goal.md](../goal.md) 「不修改 mihomo 内核」的非目标。

## 决定

- mihomo 与 `core/*.go` 继续作为代理内核，Flutter 继续负责界面与界面状态，Android VpnService 继续由 Kotlin 实现。
- Dart 中不属于界面的「应用后端」逻辑分阶段迁到 `plugins/rust_api`，经 flutter_rust_bridge 暴露给 Dart。顺序为：
  基础设施 → po0 / ggy 加白（试点）→ 配置生成与订阅更新 → 桌面 Core 进程管理；范围、验证与退出条件见
  [development/rust-migration.md](../development/rust-migration.md)。
- 每个阶段单独发版。试点结束后由维护者根据体积、内存与稳定性数据决定是否继续。
- 进入桌面 Core 进程管理阶段前另写 ADR，改写 AGENTS.md 中「桌面 Core 进程收敛归 `lib/core/desktop/`」的所有权规则。

## 后果

- 迁走的逻辑由 `cargo test` 覆盖，`scripts/vps/verify.sh` 需要加入 Rust 的 fmt / clippy / test。`flutter test` 不构建原生库，
  Dart 侧通过可注入的函数类型使用假实现，做法与 `lib/core/desktop/transport.dart` 的 `IpcServerStarter` 一致。
- 迁走的上游文件（`lib/common/task.dart`、`lib/providers/actions/setup.dart`、`lib/models/profile.dart`）以后合并上游前端时
  需要手工移植，记录在 [upstream-sync.md](../development/upstream-sync.md)。加白与桌面 Core 进程管理本来就不合并上游，不受影响。
- 界面进程多一个 Rust 运行时，安装包与常驻内存会增加，每个阶段都要测量并与基线比较。
