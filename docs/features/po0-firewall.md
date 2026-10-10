# 加白（po0 / ggy 防火墙自动加白）

入口：主导航中的 **加白**，与仪表盘、代理、配置、工具同级——桌面端在侧边栏，手机端在底部导航栏。
po0 与 ggy 两种加白服务合并在同一个页面、同一个总开关和一张混合条目列表里（见 [ADR 0014](../adr/0014-unified-whitelist.md)）；
两种服务保留各自的请求方式与执行间隔，ggy 的固定 11 秒见 [ADR 0013](../adr/0013-ggy-page.md)。

## 页面

| 区块 | 内容 |
|---|---|
| 概览卡片 | 总状态（已加白 / `n/m` 部分加白 / 未开启 / 未配置 / 执行中）、出口网段、po0 上次检查时间与 ggy 上次加白时间，右侧为「查询 po0 状态」「立即加白」 |
| 设置 | 自动加白总开关、po0 检查间隔（只有 po0 条目时显示）、ggy 固定间隔说明（只有 ggy 条目时显示） |
| Token | 混合列表（po0 在前、ggy 在后）：每行显示备注名（或凭据前 12 位）和 `po0 token` / `ggy link` 类型标记，可编辑、删除；右上角「添加 token」 |
| 白名单 | 每个有条目的服务一张结果卡片：类型标记、备注名、状态标签、结果说明、白名单占用进度条、白名单网段标签（当前出口高亮，po0 服务端的固定槽位记录带图钉） |

## 用户可见行为

| 设置 | 说明 |
|---|---|
| 自动加白 | 总开关，同时控制 po0 与 ggy。关闭时不发任何请求，也不改动路由。 |
| po0 检查间隔 | po0 每轮检查的间隔，1～3600 秒，默认 5 秒。修改后下一轮立即按新间隔执行。只影响 po0。 |
| ggy 间隔 | 固定每 11 秒请求一次链接，不可调整（ADR 0013）。 |
| 添加 token | 弹窗第一栏选类型：po0 的 token（`pgnfw_` 开头）或 ggy 的完整加白链接。类型写入对应的列表。 |
| 编辑 | 显示原类型且不可切换；凭据与备注可改。更换服务类型通过删除后重新添加完成。 |
| 立即加白 | 对所有已配置的有效条目各执行一次加白（po0 走 `POST …/add`，ggy 请求链接）。 |
| 查询 po0 状态 | 只读 `GET …/<token>`，不会占用白名单坑位；**只对 po0 执行**，没有有效 po0 token 时不显示该按钮。 |

po0 与 ggy 的条目分开保存（`tokenEntries` / `ggyEntries`），同一服务内按 trim 后的完整值查重；
po0 列表里不会接受 ggy 链接，ggy 列表里也不会接受 po0 token。没有条目的服务不发请求。

## 状态汇总

页面、首页控制中心卡片和桌面侧栏共用同一份汇总（`WhitelistSummary`）：它只统计**当前配置中的有效条目**，
已删除或已替换条目的旧结果不显示、不计入成功数；「n/m 已加白」中的 m 包含还在等待结果的有效条目，
部分成功永远不会显示成「出口已加白」。po0 与 ggy 报告的出口相同（同一 /24）时显示一个出口，
不同时页面分别显示两个服务的出口，首页卡片只显示汇总状态。

总开关关闭时保留上次结果供查看，但总状态优先显示关闭。

## 检查与加白

`Po0Firewall` 与 `GgyFirewall`（`lib/providers/po0_firewall.dart`）是两个常驻的 Riverpod notifier，共用 `WhitelistScheduler`
的调度逻辑，都跟随总开关，只各自提供条目列表与间隔；在应用完成初始化（`initProvider` 变为 true）后启动，
下表的事件对两者都生效。设计取舍见 [ADR 0004](../adr/0004-per-second-read-only-polling.md)、
[ADR 0005](../adr/0005-token-list-and-poll-interval.md) 与 [ADR 0007](../adr/0007-remove-fixed-slots.md)。

每轮对每个 po0 token：

1. 只读 `GET …/<token>`（单次请求，5 秒超时）。
2. 当前出口不在白名单 → 走常规流程 `POST …/add`（失败重试 3 次）。
3. 出口已在白名单（普通记录或服务端的固定槽位记录都算）、防火墙未启用、token 无效或请求失败 → 不写入。

ggy 的每轮直接请求加白链接本身，每次 GET 都会写入，固定 11 秒一轮。

一轮结束后等待一个间隔再开始下一轮。默认 5 秒时，被其它设备按 FIFO 挤出白名单后约 5～6 秒内自动补回。
连续失败时按间隔的 2 / 4 / 8 / 16 倍退避，最长 30 秒（间隔本身超过 30 秒时不再额外退避），成功后恢复原间隔。

| 事件 | 行为 |
|---|---|
| 启动 | 立即检查（有条目的服务） |
| 网络变化 | 丢弃复用的连接，清零退避，立即检查 |
| 回到前台 | 立即检查 |
| 增删条目 | 立即对该服务的当前列表执行一次加白（只改备注名不触发） |
| 修改 po0 间隔 | po0 按新间隔安排下一轮；ggy 的 11 秒节奏不变 |
| 打开总开关 | 由共享的 `WhitelistCoordinator` 先重新应用配置（写入直连路由），完成后再执行一次加白；一次开关变化只重载一次 |
| 关闭总开关 | 两个服务都停止安排新请求；正在执行的那次请求允许结束，但不再有下一轮 |
| Android 熄屏 | 暂停检查（不持有 WakeLock，不额外耗电） |
| Android 亮屏 | 立即检查并恢复按间隔检查 |

总开关快速反复切换时，以最新一次的意图为准收敛；手动操作（查询 / 立即加白）排队期间页面显示执行中并禁用重复点击，
因关闭开关被取消的待执行请求会清理忙碌状态。

请求复用同一条 keep-alive 连接，避免每轮一次 TLS 握手；网络变化、超时或出错时丢弃连接重新建立。
检查在后台进行时页面不会显示「执行中」，只有手动操作或开关转换才显示。
ggy 返回的 `removed_cidr` 非空（FIFO 挤掉了一条记录）时每次都写日志（`[APP] ggy firewall …`）；
日志里持续出现 `evicted` 说明 ggy 对已在名单中的网段并不幂等。po0 结果变化的日志用 `[APP] po0 firewall …`，
凭据只显示前 12 位。

### 生效范围

- 桌面端：应用运行期间持续检查；电脑休眠时自然暂停，唤醒后下一个间隔内恢复。
- Android：亮屏且应用在运行（前台或切到后台）时按间隔检查。检查逻辑运行在界面的 Flutter 引擎中，
  **从最近任务划掉 po0-clash 后检查停止**（即使 VPN 仍在运行），重新打开应用即恢复。

## 为什么需要直连路由

服务端按**请求来源 IP**识别出口网段，所以请求必须从物理网卡直接发出：

1. 请求使用独立的 `HttpClient`，绕过应用自身对 mixed-port 的代理设置（`FlClashHttpOverrides`）。代理未运行时
   `findProxy` 为 `DIRECT`；代理运行时走内核的专用直连入口 `PROXY <账号>@127.0.0.1:<端口>`。
   端口和账号都不固定：每次应用会话由系统分配一个空闲端口，并随机生成一组账号，生成配置和发请求共用。
   这个入口是总开关开启后强制写入配置的 listener `po0-direct`（`type: http`、`proxy: DIRECT`，带上述 `users`），
   内核先按入站指定的 `proxy` 分流、再看模式，所以规则、全局模式和 TUN 都改变不了它的去向，域名（ggy）也一样适用。
   入口连不上时，po0 退回普通直连（靠第 2、3 条兜底）；ggy 直接失败，因为普通直连会被 TUN 接管、把代理节点加白。
2. 总开关开启后，生成的配置还会（po0 的兜底，见 ADR 0001）：
   - 在规则最前面插入 `IP-CIDR,124.221.69.228/32,DIRECT,no-resolve`（规则模式下 TUN 捕获的流量也走直连）；
   - 向 `tun.route-exclude-address` 加入 `124.221.69.228/32`，桌面 TUN 不再接管该地址（全局模式同样有效）。
3. Android VPN 的路由表由 `VpnService.Builder` 决定，`excludeRoute` 需要 API 33，因此在 `sharedState` 中把
   `124.221.69.228/32` 从路由列表（默认 `0.0.0.0/0`）中拆分剔除。VPN 路由只在 VPN 启动时生效；由于代理运行时请求走第 1 条的
   直连入口（listener 随配置热加载），开启功能后不必再重启 VPN。

证书校验沿用应用的「检查证书」开关。po0 端点使用 Let's Encrypt IP 证书，服务端发送到 ISRG Root X1 的完整链；
传输层在系统根证书之外额外信任内置的 ISRG Root X1（`po0SecurityContext`），因为 dart:io 在两种情况下拿不到它：

- Windows：dart:io 在建立 `SecurityContext` 时一次性复制系统证书库，之后不再刷新；而 Windows 只在某个程序首次通过系统
  API 用到第三方根证书时才自动下载安装。新装或重置的系统上，应用可能先于 ISRG Root X1 安装启动，此后一直报
  `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`，直到重启应用。
- Android 7.0（API 24，应用最低版本）：系统证书库从 7.1.1 起才包含 ISRG Root X1。

macOS 把整条链交给系统 SecTrust 实时校验，不受影响。

## 配置迁移

- po0.5 及更早：逗号分隔的 token 字符串自动转换成列表（`@N` 槽位后缀被丢弃），旧的分钟间隔被忽略，检查间隔取默认 5 秒。
- 6.0：ggy 链接和 po0 token 存在同一个列表里，升级后读取配置时自动移到 ggy 列表。
- 6.1：po0 与 ggy 各有一个开关。升级后读取配置时两个开关按 OR 合并成总开关——任一开启则总开关开启，
  两边都关闭则关闭；保存的配置不再包含 `ggyEnable`，因此关闭后重新加载不会再次打开。
- 不支持固定槽位（见 [ADR 0007](../adr/0007-remove-fixed-slots.md)）：加白只走普通 `POST …/add`，旧版本保存的槽位号在
  读取配置时被忽略。服务端已有的固定槽位记录不受影响，仍会显示在白名单里。

## 代码位置

| 文件 | 职责 |
|---|---|
| `lib/common/po0_firewall.dart` | token / ggy 链接解析、/24 比较、IPv4 路由剔除、直连 listener 与出口选择、keep-alive 传输、HTTP 客户端与响应解析 |
| `lib/models/po0_firewall.dart` | `Po0FirewallProps`（总开关 + 两个条目列表 + 旧配置迁移）与结果 / 状态模型 |
| `lib/models/whitelist_summary.dart` | `WhitelistSummary`：按当前有效条目统计的纯汇总 |
| `lib/providers/po0_firewall.dart` | 调度器 `Po0Firewall`、`GgyFirewall`（共用 `WhitelistScheduler`）、共享协调器 `WhitelistCoordinator`、汇总 provider 与 `po0FirewallClientProvider` |
| `lib/plugins/po0_screen.dart` / `android/.../plugins/Po0ScreenPlugin.kt` | Android 亮屏 / 熄屏信号（`$packageName/po0_screen` 通道） |
| `lib/providers/config.dart` | `po0FirewallSettingProvider`，并入 `Config`（随备份 / 恢复） |
| `lib/common/task.dart` | 生成配置时写入直连规则与 `route-exclude-address` |
| `lib/providers/actions/setup.dart` | 生成配置时按总开关注入直连 listener（`withPo0DirectListener`）与 `directCidrs` |
| `lib/providers/state/system.dart` | Android VPN 路由剔除（跟随总开关） |
| `lib/views/po0_firewall.dart` | 统一加白页面（概览、设置、混合列表、类型选择弹窗、结果卡片） |
| `lib/enum/enum.dart` / `lib/views/navigation.dart` / `lib/pages/shell.dart` / `lib/views/control/tiles.dart` | `PageLabel.whitelist` 主导航入口、侧栏状态与首页汇总卡片 |

测试：`test/common/po0_firewall_test.dart`、`test/providers/po0_firewall_test.dart`、`test/providers/state_derived_test.dart`、
`test/providers/config_test.dart`、`test/providers/setup_action_test.dart`、`test/models/whitelist_summary_test.dart`、
`test/views/po0_firewall_view_test.dart`。
