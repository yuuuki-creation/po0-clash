# 0013. ggy 作为独立页面，固定 11 秒轮询

- 状态：已采纳，独立页面与独立开关部分已取代（见 0014）
- 日期：2026-10-03

## 背景

6.0 把 ggy 加白链接当作 po0 列表里的一种 token（添加对话框第一栏选类型），共用 po0 的开关与刷新间隔（ADR 0012）。
维护者要求把 ggy 提到与 po0 同一级，并把 ggy 的轮询固定为 11 秒：ggy 的链接每次请求都会写入，间隔不应由用户随手调到 1 秒。

## 决定

- 主导航新增 `PageLabel.ggy`，与 po0 并列；页面与 po0 共用 `lib/views/po0_firewall.dart` 的组件，按私有枚举 `_Service` 区分。
  po0 的添加对话框去掉类型选择，只收 `pgnfw_` token；ggy 页面只收 ggy 链接。
- ggy 的开关与链接作为 `Po0FirewallProps` 的新字段（`ggyEnable`、`ggyEntries`），不新增 `Config` 字段，持久化、备份恢复的上游接线不变。
  读取配置时，`tokenEntries` 里的 ggy 链接移到 `ggyEntries`，`ggyEnable` 取原来的 `enable`，6.0.x 用户升级后照常加白。
- 调度逻辑抽成 `WhitelistScheduler` mixin，`Po0Firewall` 与 `GgyFirewall` 各用一份，只提供开关、列表、间隔和日志前缀；
  ggy 的间隔为常量 `GgyFirewall.pollInterval`（11 秒）。启动、网络变化、回到前台、亮屏 / 熄屏两者都收到。
- 内核直连入口在任一开关打开时注入；`IP-CIDR` 规则、`route-exclude-address` 与 Android 路由拆分仍只跟 po0 开关走。
- ggy 页面不显示「查询状态」：对 ggy 来说查询与加白是同一个请求。
- 首页控制中心原来只有 po0 卡片，现在显示有条目的那一个；两者都有时每 5 秒轮换，计时器只在两者都有时运行。

## 后果

- 手机底栏从 5 项变为 6 项。
- ADR 0012 中「ggy 链接存于 po0 token 列表、类型由对话框选择、按 po0 刷新间隔请求」的部分由本 ADR 取代；直连入口的决定不变。
- 改 ggy 的间隔需要改代码并发版。
- 2026-10-10：po0 与 ggy 的页面与开关合并为统一加白入口（见 0014）；固定 11 秒与两套调度器的约束继续有效。
