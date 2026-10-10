# po0 与 ggy 合并为加白的实施指导

本任务把 po0 加白与 ggy 加白合并成一个名为「加白」的功能。界面只有一个入口、一个自动加白总开关和一张混合条目列表；新增条目时选择「po0 token」或「ggy 链接」。两种服务保留各自的请求方式与执行间隔。

本文供实现代理直接执行，包含已确认需求、具体实现路线、逐文件修改要求和验收用例。编写依据为 2026-10-10 的 `main`，提交 `cafdc80`。实施前重新检查当前代码；若提交已经变化，以本文描述的符号定位，不机械套用行号。

## 1 已确认需求与实现边界

### 1.1 维护者已经确认的需求

1. 原来的「po0 加白」「ggy 加白」合并为一个主导航入口，名称准确使用「加白」。
2. 新增 token 时，由用户选择类型：po0 的 token 或 ggy 的完整加白链接。
3. 使用一个「自动加白」总开关，控制两种服务。
4. 旧配置迁移规则已经明确：任意一边原来开启，新总开关就开启，两种服务都启用；原来两边都关闭，新总开关就关闭。
5. 已有 token、链接、备注和 po0 刷新间隔都保留。

旧开关的迁移真值表：

| 旧 `enable` | 旧 `ggyEnable` | 新 `enable` | 升级后的行为 |
|---|---|---|---|
| false | false | false | 两种服务都不执行 |
| true | false | true | 两种服务都执行各自已配置的条目 |
| false | true | true | 两种服务都执行各自已配置的条目 |
| true | true | true | 两种服务都执行各自已配置的条目 |

没有配置条目的类型不发请求。例如只有 ggy 链接，总开关开启后只执行 ggy。

### 1.2 本次实施采用的细节

这些细节沿用讨论中的方案，并把未指定的小交互固定下来，实施时无需再提出多套方案。

- 页面标题、导航名称、首页卡片名称都叫「加白」。
- 总开关默认关闭；新增条目不擅自打开总开关。
- 新增按钮统一叫「添加 token」，新增弹窗标题也叫「添加 token」。
- 新增弹窗默认选择 po0，两个类型均保留自己的输入格式校验。
- 编辑弹窗自动识别已有条目的类型；类型只读。更换服务类型通过删除后重新添加完成，不做跨类型编辑迁移。
- 顶部「立即加白」对所有已配置的有效条目执行一次加白。
- 顶部「查询 po0 状态」仅查询 po0；没有有效 po0 token 时隐藏该按钮。
- 总开关关闭时，两个手动按钮禁用，沿用现有页面的行为。
- 首页一张卡片汇总两种服务，不再轮换；点击固定进入「加白」。
- 混合列表按 po0 在前、ggy 在后显示，每类内部保留已有顺序；不新增拖拽排序、筛选或分页。
- 继续沿用现有的列表区和结果区，不额外把它们重做成新的详情系统。

### 1.3 范围限制

- 本任务不调整 ggy 的 11 秒执行间隔，也不把 ggy 放入 po0 的可调轮询间隔。
- 不改服务端接口、请求重试次数、证书、直连传输、内核进程所有权或 Android 服务生命周期。
- 不做全仓库的 po0 名称替换。产品名称仍然是 `po0-clash`；接口、listener、插件通道和内部持久化字段可以继续保留 po0 名字。
- 不删除用户条目，不恢复固定槽位，不新增单条目开关。
- 不修改版本号，不创建或推送 release tag，不触发 release workflow。
- 不借机升级依赖或重做其他页面。

## 2 实施前必须读的仓库约束

依次阅读：

1. 根目录 `AGENTS.md`。
2. `.agents/fork.md`、`.agents/project.md`、`.agents/commands.md`、`.agents/rules.md`。
3. `.agents/architecture.md` 中与 provider、配置、Core 接线有关的部分。
4. `.agents/skills/ui-work/SKILL.md`、`.agents/skills/localization/SKILL.md`、`.agents/skills/provider-tests/SKILL.md`。
5. `docs/features/po0-firewall.md`、`docs/features/glass-ui.md`。
6. `docs/adr/0012-direct-listener-and-ggy.md`、`docs/adr/0013-ggy-page.md`。
7. `docs/development/build.md`、`docs/development/upstream-sync.md`。

`.agents/fork.md` 和 ADR 0013 当前仍要求 ggy 独立页面、独立开关。维护者本次明确要求合并，已经取代这两个要求；实施时同步修订相应文档。ADR 0013 关于固定 11 秒与两套调度器的约束继续有效。

实施前执行 `git status --short --branch`，保留他人的未提交修改。开发分支按实际运行环境的规则创建：Codex 默认使用 `codex/` 前缀；其他执行环境遵循仓库分支约定。不要自行推送或发版。

## 3 当前结构与目标结构

### 3.1 当前代码的职责

| 文件或符号 | 当前职责 |
|---|---|
| `lib/models/po0_firewall.dart` 的 `Po0FirewallProps` | 保存 `enable`、`tokenEntries`、`pollSeconds`、`ggyEnable`、`ggyEntries` |
| 同文件的 `safeFromJson` | 损坏配置兜底、旧 token 字符串迁移、6.0 混合列表迁移 |
| `lib/common/po0_firewall.dart` 的 `Po0TokenKind` | 识别 po0 与 ggy 类型 |
| 同文件的 `po0TokensOf`、`ggyLinksOf` | 分别筛出有效且不重复的请求条目 |
| `lib/providers/po0_firewall.dart` 的 `Po0Firewall` | po0 的调度器 |
| 同文件的 `GgyFirewall` | ggy 的调度器，间隔常量 11 秒 |
| 同文件的 `WhitelistScheduler` | 两种服务共用的调度、退避、队列、日志逻辑 |
| `lib/views/po0_firewall.dart` | 两个页面及共享组件，按 `_Service` 区分 |
| `lib/views/navigation.dart` | 注册两个主导航入口 |
| `lib/common/l10n_labels.dart` | 页面名称与说明的本地化映射 |
| `lib/pages/shell.dart` 的 `_SidebarItem` | 桌面侧栏分别显示两种服务状态 |
| `lib/views/control/tiles.dart` 的 `WhitelistStatusCard` | 首页卡片，每 5 秒轮换两种服务 |
| `lib/manager/app_manager.dart` | 应用初始化、前台恢复、Android 屏幕事件 |
| `lib/manager/connectivity_manager.dart` | 网络变化事件 |
| `lib/providers/actions/setup.dart` | 注入专用 DIRECT listener 与 po0 路由排除 |
| `lib/providers/state/system.dart` | Android 的 po0 地址路由拆分 |

### 3.2 目标结构

```text
Po0FirewallProps
  enable             一个总开关
  tokenEntries       po0 条目，持久化列表保持原字段
  ggyEntries         ggy 条目，持久化列表保持原字段
  pollSeconds        仅 po0 使用

WhitelistCoordinator 一个共享协调器
  负责总开关变化时的路由重载与两个调度器的放行
  不持有轮询计时器，不直接发送 HTTP 请求

Po0Firewall          继续只执行 po0 条目
GgyFirewall          继续只执行 ggy 条目
  两者都读取 enable，执行间隔仍各自独立

WhitelistView        一个统一页面
WhitelistSummary    同一份状态汇总，供页面、首页、侧栏使用
PageLabel.whitelist  一个主导航目的地
```

界面合并列表，持久化仍保存两个列表。这样无需引入新的配置版本号、条目类型字段或跨列表排序字段，也能保留旧备份格式。

## 4 配置模型与迁移

### 4.1 修改目标字段

在 `lib/models/po0_firewall.dart` 中把配置模型改为以下形状，保留已有类名和 JSON 外层字段：

```dart
const factory Po0FirewallProps({
  @Default(false) bool enable,
  @Default([]) List<Po0TokenEntry> tokenEntries,
  @Default(5) int pollSeconds,
  @Default([]) List<Po0TokenEntry> ggyEntries,
}) = _Po0FirewallProps;
```

`enable` 从「po0 开关」变成「加白总开关」。删除模型中的 `ggyEnable`。`Config.po0FirewallProps`、`po0FirewallSettingProvider` 和备份恢复的接线名称保持原样。

不要保留一个隐藏的可写 `ggyEnable`，也不要让 UI 每次切换时同时写两个开关。真正的总开关必须只有一个配置状态。

### 4.2 迁移顺序

`safeFromJson` 仍然在 `decodeOrRestoreDefault` 内处理所有转换与解码。顺序固定为：

1. 旧的 `tokens` 字符串转换为 `tokenEntries`，保留现有优先级：有 `tokenEntries` 时不再使用旧字符串。
2. 兼容 6.0 混合列表，把其中有效 ggy 链接移入 `ggyEntries`。
3. 把旧的两个开关合成一个 `enable`，并从传给生成解码器的 map 中移除 `ggyEnable`。
4. 调用生成的 `Po0FirewallProps.fromJson`。

第二步不再创造 `ggyEnable`。正常的新格式已经有两个分开的列表，不应改变其内容或顺序。

旧列表若同时带有 `ggyEntries` 和混在 `tokenEntries` 中的有效 ggy 链接，不能因为 `ggyEntries` 字段存在就丢掉旧链接：保留已有 `ggyEntries`，再追加迁移出的链接；完整链接重复时已有 ggy 条目优先，保留其备注。po0 列表内有效 ggy 链接迁出后不能同时留下副本。

不要在迁移中清洗删除其他无法识别的条目；仍由现有的 `po0TokensOf`、`ggyLinksOf` 决定哪些条目可以请求。列表类型、条目形状损坏时保留现有解码失败兜底机制。

### 4.3 合并开关的伪代码

```text
读取 enable 与 ggyEnable
  缺失或 null 按 false 处理
  非 null 且不是 bool 的值抛出 FormatException
  不把字符串 "true"、"yes" 或数字 1 转为 true

newEnable = oldEnable || oldGgyEnable
建立新的 map，复制其他字段
写入 enable = newEnable
移除 ggyEnable
返回这个新 map
```

转换失败由 `safeFromJson` 的现有兜底恢复默认配置，不要让坏配置使应用启动崩溃。

新配置只有 `enable`，没有 `ggyEnable`；因此重新加载时计算的是 `enable || false`，值不会改变。迁移应当幂等。

### 4.4 必须防止再次打开的错误

下面的情况必须通过测试：

1. 加载旧配置 `enable: false, ggyEnable: true`，迁移为总开关开启。
2. 用户关闭新总开关。
3. 保存配置，确认 JSON 中没有 `ggyEnable`。
4. 再次加载保存结果，总开关仍为 false。

如果为了兼容继续保存 `ggyEnable: true`，下一次按 OR 迁移就会再次开启。这种实现不合格。

### 4.5 迁移示例

旧配置：

```json
{
  "enable": false,
  "ggyEnable": true,
  "tokenEntries": [{"token": "pgnfw_home", "name": "家里"}],
  "ggyEntries": [{"token": "https://www.guguyun.com/f/whitelist?token=ctecsfw_demo", "name": "ggy"}],
  "pollSeconds": 20
}
```

迁移并保存后：

```json
{
  "enable": true,
  "tokenEntries": [{"token": "pgnfw_home", "name": "家里"}],
  "ggyEntries": [{"token": "https://www.guguyun.com/f/whitelist?token=ctecsfw_demo", "name": "ggy"}],
  "pollSeconds": 20
}
```

上述凭据均为测试占位值。测试和说明不得使用真实用户 token 或真实加白链接。

## 5 总开关与调度协调

### 5.1 两套调度器继续存在

在 `lib/providers/po0_firewall.dart` 中：

- `Po0Firewall._enabledIn(setting)` 读取 `setting.enable`。
- `GgyFirewall._enabledIn(setting)` 也读取 `setting.enable`。
- po0 继续调用 `po0TokensOf(setting.tokenEntries)`。
- ggy 继续调用 `ggyLinksOf(setting.ggyEntries)`。
- po0 继续使用 `pollIntervalOf(setting)`，范围 1～3600 秒，默认 5 秒。
- ggy 继续使用 `GgyFirewall.pollInterval`，固定 11 秒。
- 失败退避、网络切换、前台恢复、屏幕开关和日志行为保留。

### 5.2 不能直接让两个调度器分别重载路由

现在 `WhitelistScheduler._handleSettingChanged` 在自己的开关变化时调用 `_applyEnable`；`_applyEnable` 内会执行 `reapplyRouting()`。如果仅把两个 `_enabledIn` 都改成 `setting.enable`，一个总开关会触发两次独立的 `applyProfile`，并使两个放行时刻不同。

本次明确采用共享协调器解决这个问题：

1. 在同一个 provider 文件内增加 keep-alive 的 `whitelistCoordinatorProvider`，提供 `WhitelistCoordinator`。
2. 协调器唯一监听 `po0FirewallSettingProvider.select((it) => it.enable)` 的变化，负责因总开关变化产生的 profile 重载。
3. 两个 scheduler 自己不再因 enable 变化调用 `reapplyRouting`；它们仍监听各自条目和间隔变化。
4. 协调器通过小型方法通知两个 scheduler 路由转换开始、完成。
5. 不把这份协调状态放进 widget。直接写 provider、备份恢复和 UI 点击都必须走同一套配置监听。

可以使用与现有 `po0FirewallClientProvider` 相同的函数 provider 形式，让 provider 创建一个普通协调器对象。实现名字按上述名称保持一致，方便测试定位；无需新建通用事件总线。

### 5.3 协调器的具体行为

建议提供如下职责对应的方法；下面是行为说明，不是可直接复制的完整 Dart 实现：

```text
beginRoutingTransition(version)
  scheduler 记录最新 version
  标记 routingPending
  取消自己的轮询 timer
  清除旧的待执行请求与旧退避

finishRoutingTransition(version)
  version 不是最新版本时忽略
  清除 routingPending
  若当前总开关关闭，不启动新请求
  若当前总开关开启、scheduler 已 start 且有有效条目
    立即执行一次 whitelist，然后恢复各自轮询
```

协调器维护一个递增的版本号和一个串行处理中的标记。处理流程：

1. 总开关变化时，立刻递增版本号，同时让两个 scheduler 进入 `routingPending`。
2. 若没有 profile 重载正在执行，开始处理；已经在执行则只记录最新意图，不并行启动第二次重载。
3. 调用现有 `setupActionProvider.notifier.applyProfile(silence: true)`，遵守原有 `initProvider` 门槛。
4. 等待结果。若期间版本号变化，再按最新配置串行处理，不能放行旧版本。
5. 最新配置处理完成后，才通知两个 scheduler 结束转换。
6. 已卸载的 provider 不得继续写状态或启动请求；异常必须清理处理中的标记，并保留现有错误日志行为。

单次开关变化应只重载一次；快速反复切换时，可能为最新配置再重载一次，这是收敛所需。不要按每种服务分别重载。

方法接线还必须满足以下细节，否则只写一个协调器类仍然会存在竞态：

- `_handleSettingChanged` 发现 `prev.enable != next.enable` 时不再自行应用路由，也不在同一次通知中因列表变化额外发送请求；总开关转换由协调器完成后统一处理最新列表。
- `_run` 和 `_scheduleNext` 都检查 `routingPending`。尤其不能让一次旧的 HTTP 请求结束后通过 `_scheduleNext` 绕过路由门槛。
- 请求发出时记录所属版本；完成后发现开关转换版本已过期，不把它当成新一轮检查完成，也不清除新一代的手动忙碌状态。
- 丢弃过期结果仍要释放 `_inFlight`。路由门槛已释放时继续处理最新队列，尚未释放时等待协调器通知；不能直接 return 后把新手动任务永久卡在队列里。
- 协调器最新处理完成时，按最新列表执行一次加白，清除被这次加白覆盖的旧队列意图。若仍有先前请求在执行，沿用 scheduler 的串行队列等待它结束。
- 不能让两个 scheduler 的回调注册顺序决定安全性。调度器收到 enable 变化时应立即自行进入暂停状态；这个本地暂停只设门槛、取消 timer，不另增或覆盖共享版本。共享协调器给出转换版本。两个回调无论谁先收到通知都不能发新请求。
- `applyProfile` 返回 `bool`。处理 false 返回值和抛异常两条失败路径，二者都不能留下永远不释放的协调状态。

启用时必须先处理路由，再开始新的请求。关闭时立即取消后续调度；已经发出的 HTTP 请求无需强制取消，但不能在关闭后排队发出下一轮，也不能因为旧请求完成而把总开关或界面恢复成开启状态。

若路由应用失败，沿用既有错误处理和传输策略，不另加新的代理回落。特别是 ggy 不能为了成功而退回可能被 TUN 接管的普通 socket。协调器释放门槛时必须检查最新总开关；继续运行的请求仍由现有传输层报告错误并退避。

### 5.4 初始化与事件接线

在 `lib/manager/app_manager.dart` 的 `initProvider` 为 true 的分支中，先初始化共享协调器，再调用两个 scheduler 的 `start()`。启动路径继续使用初始化流程已经生成的 profile，不因协调器构造而额外立即重载一次。

现有两种服务的网络变化、前台恢复、Android 亮屏和熄屏通知必须全部保留。不要只留下 po0 的通知，也不要用页面是否可见决定是否调度。

总开关开启但某类没有条目时，该 scheduler 不发请求、不创建空轮询 timer。`_scheduleNext` 也应检查有效条目是否为空；删掉某类最后一项后不能留下持续空转的 timer。

### 5.5 手动操作与待执行状态

「立即加白」读取最新有效列表，只通知有条目的 scheduler 执行 `whitelist()`；「查询 po0 状态」只通知 po0 执行 `query()`。UI 不调用 HTTP client。

当前 `_run` 碰到正在运行的后台请求时只记录 `_queued` 然后返回；这意味着 `await whitelist()` 不一定表示新请求已经执行完。不要仅用 widget 内的 `await Future.wait(...)` 作为按钮忙碌状态的唯一依据。

本次把 scheduler 的 `isRunning` 明确定义为「存在待执行或正在执行的手动请求」：

- 手动请求进入队列时就显示忙碌，后台例行 poll 保持静默。
- 开启总开关所触发的路由准备和立即加白也计入忙碌；关闭状态的文案优先级仍最高。
- 页面汇总两个 scheduler 的 `isRunning`；任何一个有手动任务，两枚手动按钮都禁用。
- 待执行的手动请求因关闭开关而取消时，必须清理忙碌状态。
- 成功、异常、dispose 都必须清理；不能留下永久转圈或永久禁用。
- 保留现有请求合并优先级 `poll < query < whitelist`；不要为了两个按钮新增第三套请求队列。
- enable 转换已安排立即加白时，不要再执行同一转换期间排队的相同加白，造成双发。

## 6 路由生成的改动

### 6.1 修改 setup 接线

`lib/providers/actions/setup.dart` 的 `getProfile` 当前读取 `po0FirewallEnable` 与 `ggyFirewallEnable`。改为只读取 `setting.enable`，局部变量建议叫 `whitelistEnable`。

- `whitelistEnable` 为 true 时，继续在覆写脚本处理之后注入 `withPo0DirectListener`。
- 继续传入 `directCidrs: whitelistEnable ? const [po0FirewallDirectCidr] : []`。
- 关闭时不注入本功能的专用入口与额外 CIDR。
- 不因为没有 po0 条目就额外改变路由策略。总开关开启时统一保留现有 po0 地址排除，方便以后添加 po0 条目无需引入第二套路由切换条件。

### 6.2 保留 Android 路由拆分

`lib/providers/state/system.dart` 当前已经读取 `setting.enable`。保留这一逻辑，必要时只把局部变量改名，说明它现在是总开关。

总开关开启时依旧使用 `excludeIpv4Route(..., po0FirewallDirectCidr)`；关闭时使用原始路由。不要改 Kotlin VPN 实现，也不要增加 VPN 重启要求。

### 6.3 禁止改变的传输行为

`lib/common/po0_firewall.dart` 中下面这些行为必须保持：

- `Po0DirectTransport` 绕过全局 `HttpOverrides`。
- 代理运行时经过带会话随机认证的 `po0-direct` listener，走物理网络 DIRECT 出口。
- listener 名字、动态端口与随机认证机制不变。
- `po0FindProxy` 只有 po0 固定 IP 可以使用 `PROXY ...; DIRECT` 回落。
- ggy 域名不能新增普通 DIRECT 回落。
- po0 查询是只读 GET；加白是 POST add。
- ggy 的 GET 会写入；不要把它用于统一的「查询状态」。
- 证书、keep-alive、超时、限流退避和 `removed_cidr` 日志保持。

本任务通常无需改这份文件的 HTTP 逻辑。如为了视图组合增加纯条目辅助函数，可以放在其附近；不要把调度计时器放进 common。

## 7 统一列表与状态汇总

### 7.1 条目的内部定位

视图中的混合条目需要至少携带：服务类型、原列表中的索引、`Po0TokenEntry`。它们可以是 Dart record，不必新增持久化模型。

显示列表可以保留现有配置中未能通过校验的条目，方便用户编辑或删除；请求与统计的有效条目通过 `po0TokensOf`、`ggyLinksOf` 取得。非法条目不发请求；若列表只有非法条目，概览按无有效条目处理。

编辑和删除要按服务类型返回正确的配置列表。不能把混合列表的全局索引直接拿去 `removeAt` 原始的 po0 或 ggy 列表。

弹窗打开后，配置可能因为备份恢复或其他写入变化。提交时应重新读取当前配置，校验目标仍对应原条目；目标不存在时不能误改另一个条目。新增时也要在实际写入前检查最新列表的重复值。

### 7.2 结果必须关联到真实条目

目前 `Po0TokenResult` 只有截断的 `label`，不能据此区分前 12 位相同的两个 token，也不能安全关联修改后的列表。

实施路线是在 `Po0TokenResult` 中增加可空的内存字段 `String? tokenValue`。HTTP client 创建结果时可以不设置；scheduler 在写入结果状态之前统一附上执行时对应的完整 token 值。汇总在各自服务范围内按完整值匹配结果，再从当前配置读取备注。

- 字段只用于内存匹配，不加入用户配置或备份。
- 不显示、不记录完整值；展示继续使用 `Po0Token.label`。
- 不直接打印整个结果对象；该结果类必须使用 `@Freezed(toStringOverride: false)`，防止新增凭据字段进入自动生成的字符串。其他新增汇总类也不要生成或拼接包含完整凭据的调试字符串。
- key 可以使用 `(service, tokenValue)` 作为内部组合，但不能把这种含秘密的 key 写进日志。
- 测试提供的 provider 结果也要带匹配的 `tokenValue`；没有匹配身份的结果不能算作某个条目已成功。

当一轮请求完成时，按最新配置过滤结果：已删除、已替换的条目不显示、不进入成功数；备注取最新值。总开关关闭时可以保留上次结果供查看，但概览必须优先显示关闭状态。

### 7.3 唯一的汇总计算

新增纯 Dart 的 `WhitelistSummary` 与汇总函数，建议放在 `lib/models/whitelist_summary.dart`，并从 `lib/models/models.dart` 导出。它只接收配置与两套状态，不依赖 widget、HTTP 或 timer；必要的本地化和颜色选择仍放在 UI 层。

页面、首页卡片和侧栏都使用这份汇总，不能各自再写一套成功数判断。可增加一个只派生数据的 Riverpod provider，使调用点统一订阅配置和两套状态。

至少提供：

- `enabled`：总开关。
- `total`：当前配置中去重后的有效 po0 token 数加有效 ggy 链接数。
- `applied`：与当前有效条目匹配，且结果为 `applied` 的数量。
- `waiting`：有效但尚无匹配结果的数量。
- `isRunning`：有有效条目的任意 scheduler 存在手动任务。
- 两种服务各自的最后执行时间，用于页面说明。
- 当前有效条目与匹配结果，便于结果区复用；无需复制到可写配置。

总状态的优先级：

| 条件 | 显示 |
|---|---|
| 总开关关闭 | 自动加白未开启 |
| `total == 0` | 添加 token 或链接后开始加白 |
| 有手动请求等待或执行 | 执行中… |
| 所有有效条目都无结果 | 等待首次执行 |
| `applied == total` | 出口已加白 |
| 其余情况 | `applied/total` 已加白 |

等待中的条目也在分母中。例如配置了两个条目，只有一个返回成功、另一个尚无结果，显示「1/2 已加白」，绝不能显示「出口已加白」。

颜色复用现有 tone：关闭与等待使用 neutral；全部成功使用 success；部分成功或仍等待部分结果使用 warning；已得到失败结果且没有成功或待返回条目时使用 danger。

po0 与 ggy 可能返回不同的出口表示。先用现有 `sameC24` 比较：相同网段可显示一个出口；确实不同则在页面分别显示 po0 与 ggy 的出口，不从两个结果中随便取第一个宣称是共同出口。首页空间不足时可以只显示汇总状态，避免错误的单一出口。

两个时间分别标注服务名。不要把两套检查合成一个没有说明的「每 X 秒」，因为它们执行间隔不同。

## 8 页面与新增弹窗

### 8.1 页面布局

在 `lib/views/po0_firewall.dart` 中提供唯一的 `WhitelistView`，替代 `Po0FirewallView` 和 `GgyFirewallView`。文件名可以保持不变，避免与本功能无关的重命名。

```text
加白

概览
  总状态：2/3 已加白
  po0 上次检查时间 / ggy 上次加白时间
  [查询 po0 状态] [立即加白]

设置
  自动加白                         [总开关]
  po0 检查间隔                     [可编辑]
  ggy 每 11 秒自动加白              [说明文字]

Token                              [添加 token]
  [po0] 家里    pgnfw_demo…         [编辑] [删除]
  [ggy] ggy     ctecsfw_dem…        [编辑] [删除]

白名单结果
  [po0] 家里  已加白  占用数与网段
  [ggy] ggy   已加白  结果说明

沿用现有直连说明
```

只有有效 po0 token 时显示 po0 间隔设置；只有有效 ggy 链接时显示固定间隔说明。两种都有时同时显示。无条目时保留总开关、添加入口和空状态提示。

保持现有窄屏换行、宽屏布局和最大内容宽度，不引入一套新的视觉风格。使用 `GlassSurface`、`GlassButton`、`GlassSegmented`、`GlassPill` 与 `context.glass`；圆角来自 `AppShape`、`AppRadius`，动画使用 `Durations` 与 `Easing`。

### 8.2 弹窗行为

新增弹窗从上到下：

1. 类型选择，使用已有 `GlassSegmented<Po0TokenKind>` 或仓库既有选择组件。
2. 当前类型的输入框。
3. 备注名，可选。
4. 取消、提交。

| 类型 | 标签 | 占位示例 | 校验函数 | 输入限制 |
|---|---|---|---|---|
| po0 | po0 token | `pgnfw_xxx` | `isPo0Token` | 现有 password 限制 |
| ggy | ggy 链接 | `https://www.guguyun.com/…?token=ctecsfw_xxx` | `isGgyLink` | 现有 URL 限制 |

切换类型后立即更新标签、占位、输入限制和校验提示。使用一个输入控制器，保留已经输入的文字，让用户选择正确类型后继续；不能因为保留了上一类型内容就跳过当前类型校验。

提交时去掉值两端的空白，备注也 trim。不要改写完整 ggy URL 的路径、查询参数、编码或参数顺序；不要只保存 URL 内的 token。

同类条目按 trim 后的完整值检查重复，编辑时排除当前条目。URL 重复判断沿用目前的完整字符串规则，不新增服务器身份推测或 URL 归一化。

弹窗返回值至少包含 `kind` 与 `Po0TokenEntry`。调用方根据类型更新 `tokenEntries` 或 `ggyEntries`，不能因为页面合并就把 ggy 写回 po0 列表。

### 8.3 编辑与删除

- 点击一行或编辑按钮进入编辑弹窗。
- 编辑时显示原服务类型，类型不可切换；输入值和备注可修改。
- 只改备注不触发 HTTP 请求；各展示区应即时使用新备注。
- 修改凭据、增加或删除条目时，保留各自 scheduler 现有的立即检查或加白行为。
- 删除继续使用确认对话框；按当前服务类型显示 token 或链接的删除提示。
- 列表与结果卡片都显示 po0 或 ggy 类型标记，不能仅依赖图标辨认。
- 完整凭据只出现在用户主动打开的输入框中，普通列表、结果、摘要、错误信息和日志只显示脱敏标识。

## 9 导航与首页

### 9.1 单一导航目的地

在 `lib/enum/enum.dart` 的 `PageLabel` 中，用 `whitelist` 替代 `po0` 和 `ggy`。本次检查的 `AppState.pageLabel` 是运行时状态，没有 JSON 持久化；无需为导航新增配置迁移。

在 `lib/views/navigation.dart` 删除两个旧入口，注册一个：

```text
label: PageLabel.whitelist
icon: shield 图标
builder: WhitelistView(key: GlobalObjectKey(PageLabel.whitelist))
```

在 `lib/common/l10n_labels.dart` 的两个 exhaustive switch 中更新名称与说明，确保没有遗漏新的枚举值。在 `lib/pages/shell.dart` 中用一个 `PageLabel.whitelist` 分支显示共享汇总状态。

检查 `lib/views/views.dart` 的导出与所有调用点。不要留下没人使用的旧页面类；仓库有 dead-file/declaration 相关检查。

### 9.2 首页卡片

在 `lib/views/control/tiles.dart` 中：

- 保留对外名字 `WhitelistStatusCard`，减少首页布局接线变化。
- 删除 `whitelistPagesOf`、`WhitelistStatusCard.rotation`、`_turn`、轮换 timer 及其专用监听。
- 若不再有本地状态，把卡片改成 `ConsumerWidget`。
- 名称固定为「加白」，数据来自共享汇总。
- 点击固定跳转 `PageLabel.whitelist`。
- 可以保留现有针对内容变化的短过渡，不保留每 5 秒自动切换。
- 不修改 `ControlCenterView` 中其他卡片和布局。

## 10 本地化

修改四份 ARB 源文件，四份必须有相同的 key：

- `arb/intl_en.arb`
- `arb/intl_zh_CN.arb`
- `arb/intl_ja.arb`
- `arb/intl_ru.arb`

推荐新增或替换为这些明确的 key，参数形状以实现所需的 ARB 占位符为准：

| key | 中文 | 英文 |
|---|---|---|
| `whitelistNav` | 加白 | Whitelist |
| `whitelistTitle` | 加白 | Whitelist |
| `whitelistDesc` | 自动把本机出口 IP 加入 po0 或 ggy 白名单 | Automatically whitelist this device's exit IP with po0 or ggy |
| `whitelistAutoDesc` | po0 按设置间隔检查，ggy 每 11 秒加白；安卓仅在亮屏时执行 | po0 checks at the configured interval; ggy whitelists every 11 seconds. On Android, runs only while the screen is on |
| `whitelistNoEntries` | 添加 token 或链接后开始加白 | Add a token or link to start whitelisting |
| `whitelistEntriesEmptyDesc` | 添加 po0 token 或 ggy 完整加白链接，每项分别执行 | Add a po0 token or a full ggy whitelist link; each entry runs separately |
| `whitelistEntryType` | 类型 | Type |
| `whitelistPo0Token` | po0 token | po0 token |
| `whitelistGgyLink` | ggy 链接 | ggy link |
| `whitelistQueryPo0` | 查询 po0 状态 | Query po0 status |
| `whitelistPo0Interval` | po0 检查间隔 | po0 check interval |
| `whitelistGgyInterval` | ggy 每 {seconds} 秒加白 | ggy whitelists every {seconds} seconds |
| `whitelistLastPo0` | po0 上次检查：{time} | Last po0 check: {time} |
| `whitelistLastGgy` | ggy 上次加白：{time} | Last ggy whitelist: {time} |

`po0AutoWhitelist`、`po0AddToken`、`po0EditToken`、结果状态等本来就是通用文字的 key 可以继续复用。不要为了命名整齐把所有旧 key 和内部符号都改一遍。

已有不再被引用的页面专属导航、标题或说明 key，应在确认没有调用点后从四份源 ARB 同步移除。仍用于输入错误、删除提示、client 结果的服务专属 key 保留。日语和俄语提供实际翻译，不能仅复制英文交差。

新增 key 的日语与俄语建议译文如下；占位符名字必须与中文和英文相同：

| key | 日语 | 俄语 |
|---|---|---|
| `whitelistNav` | ホワイトリスト | Белый список |
| `whitelistTitle` | ホワイトリスト | Белый список |
| `whitelistDesc` | この端末の出口 IP を po0 または ggy のホワイトリストに自動追加 | Автоматически добавлять исходящий IP устройства в белый список po0 или ggy |
| `whitelistAutoDesc` | po0 は設定した間隔で確認し、ggy は 11 秒ごとにホワイトリストへ追加します。Android では画面点灯中のみ実行します | po0 проверяет список с заданным интервалом, ggy добавляет IP каждые 11 секунд. На Android выполняется только при включённом экране |
| `whitelistNoEntries` | token またはリンクを追加すると開始します | Добавьте токен или ссылку, чтобы начать |
| `whitelistEntriesEmptyDesc` | po0 token または ggy の完全なリンクを追加してください。各項目は個別に実行されます | Добавьте токен po0 или полную ссылку ggy. Каждая запись обрабатывается отдельно |
| `whitelistEntryType` | 種類 | Тип |
| `whitelistPo0Token` | po0 token | Токен po0 |
| `whitelistGgyLink` | ggy リンク | Ссылка ggy |
| `whitelistQueryPo0` | po0 の状態を確認 | Проверить статус po0 |
| `whitelistPo0Interval` | po0 の確認間隔 | Интервал проверки po0 |
| `whitelistGgyInterval` | ggy は {seconds} 秒ごとに追加 | ggy добавляет IP каждые {seconds} с |
| `whitelistLastPo0` | po0 の最終確認：{time} | Последняя проверка po0: {time} |
| `whitelistLastGgy` | ggy の最終追加：{time} | Последнее добавление ggy: {time} |

使用 `context.appLocalizations` 或 `currentAppLocalizations`，不要写硬编码中文或新建运行时 `Intl.message` key。生成代码不手改。

## 11 逐文件实施清单

| 文件 | 修改要求 |
|---|---|
| `lib/models/po0_firewall.dart` | 删除配置 `ggyEnable`；迁移旧开关 OR；改进旧混合列表处理；结果增加内存匹配身份 |
| `lib/models/whitelist_summary.dart` | 新增纯汇总模型或函数，按有效当前条目统计 |
| `lib/models/models.dart` | 导出新增汇总文件 |
| `lib/providers/po0_firewall.dart` | 两套调度器共用 `enable`；新增共享协调器及派生汇总；处理手动队列忙碌、空列表与旧结果 |
| `lib/providers/actions/setup.dart` | 删除旧双开关读取，使用一个总开关注入 listener 和 directCidrs |
| `lib/providers/state/system.dart` | 核对 Android 路由仍跟随总开关，必要时改局部名字 |
| `lib/manager/app_manager.dart` | 调度器启动前初始化协调器，保留两套生命周期通知 |
| `lib/manager/connectivity_manager.dart` | 通常不需改；确认两种服务网络通知保留 |
| `lib/views/po0_firewall.dart` | 唯一 `WhitelistView`；统一概览、总开关、混合列表、类型选择弹窗和结果 |
| `lib/enum/enum.dart` | 单一 `PageLabel.whitelist` |
| `lib/common/l10n_labels.dart` | 更新两个页面 switch |
| `lib/views/navigation.dart` | 注册单一加白入口 |
| `lib/pages/shell.dart` | 使用统一状态作为加白入口副标题 |
| `lib/views/control/tiles.dart` | 删除轮换、固定统一入口、显示汇总 |
| `lib/views/views.dart` | 核对导出，旧页面引用清理 |
| `arb/intl_*.arb` | 四语言文案同步 |
| `lib/models/generated/po0_firewall.*`、`lib/providers/generated/po0_firewall.g.dart`、`lib/l10n/` | 仅通过生成命令更新 |
| `test/providers/config_test.dart` | 迁移、保存恢复、损坏配置测试 |
| `test/providers/po0_firewall_test.dart` | 总开关、协调器、间隔、并发、队列与空列表测试 |
| `test/models/whitelist_summary_test.dart` | 新增有效条目、结果关联和状态汇总测试 |
| `test/views/po0_firewall_view_test.dart` | 两个页面用例改成统一页面与混合条目测试 |
| `test/views/control_center_test.dart` | 轮换测试替换为汇总与统一导航测试 |
| `test/providers/state_derived_test.dart` | 导航断言与总开关路由断言 |
| `test/providers/setup_action_test.dart` | 核对总开关的 setup 接线及唯一 profile 重载 |
| `test/widgets/views_smoke_test.dart` | 使用 `WhitelistView`，更新条目名字 |
| `test/enum/enum_test.dart` 与本地化相关测试 | 检查 PageLabel 变化和四语言新增 key |

`lib/providers/config.dart`、`lib/models/config.dart`、`lib/providers/actions/backup.dart` 通常无需结构改动。外层配置名字、provider 名字保持不变；用测试证明备份恢复正确，而不是另造一条保存路径。

## 12 建议实施顺序

1. 先新增 ADR 0014，并更新受其取代的仓库说明，写入已确认的需求与不变的 11 秒规则。
2. 修改配置模型与迁移，增加迁移用例。
3. 修改 scheduler，增加协调器，先验证总开关与路由应用顺序。
4. 接好 `setup.dart` 所在的 `lib/providers/actions/setup.dart` 和 Android 派生路由；不要误改根目录打包脚本 `setup.dart`。
5. 增加结果身份与纯汇总模型、测试。
6. 添加四语言文案并生成本地化，使页面可以引用新 getter。
7. 改统一页面、类型弹窗和混合列表。
8. 改导航、侧栏、首页卡片，清理旧页面和轮换逻辑。
9. 更新现有 widget、provider、导航测试，再做统一代码生成与格式检查。
10. 完成聚焦验证和 CI 等价验证，检查 diff，提供验收结果。

模型或 provider 改动后及时运行代码生成，避免拿尚未更新的 generated API 判断源码是否正确。失败时先检查是否缺少生成，不要手动修 generated 文件。

## 13 测试要求

以下用例是本次改动的验收范围。可以合并到参数化测试，但不能只把旧断言改成新名字而跳过实际行为。

### 13.1 配置与备份

- 四种旧开关组合全部覆盖，并经过 `Config.fromJson` 这条真实接线验证。
- 缺少两个开关默认关闭；缺少 `ggyEnable` 的新配置按 `enable` 保持。
- 旧 6.0 混合列表仍正确拆分，备注不丢失。
- 已分开的两个列表仍保留内容与内部顺序。
- 同时存在 ggy 列表和混合旧链接时不丢条目，完整重复链接按既定优先级处理。
- 旧字符串 token、旧分钟间隔、旧 slot 的既有迁移继续通过。
- `pollSeconds` 的已保存值保留。
- 保存 JSON 不包含 `ggyEnable`。
- 迁移开启后关闭，再 JSON 保存恢复，仍关闭。
- 两种条目、备注、间隔和总开关经过 `jsonEncode` / `jsonDecode` 后 round-trip 一致。
- 错误 bool、损坏列表等配置仍由 `safeFromJson` 兜底，不能启动崩溃。

### 13.2 调度与路由

- 总开关关闭时两种服务的 start、poll、网络变化、手动调用都不发送请求。
- 总开关开启时同时执行有效 po0 与 ggy 条目。
- 只有 ggy 条目时也能开启、关闭和重新开启，不依赖存在 po0 token。
- 两个列表都为空时无 HTTP 请求、无轮询 timer。
- 从关闭切换到开启只调用一次 profile 重载；重载未完成之前两种服务都不开始新请求。
- 关闭也只重载一次，两个 scheduler 都停止安排新请求。
- 用可控 `Completer` 测开 → 关 → 开，旧转换完成不能覆盖新意图。
- 单个服务的请求已经在执行时关闭，允许其完成，但不能继续下一轮。
- 删除某类最后一项后，该类不继续空轮询；另一类继续正常运行。
- 改 po0 间隔不会改变 ggy 的 11 秒节奏。
- 只改备注不产生新请求，显示备注更新。
- 背景 poll 不显示忙碌；排队中的手动任务显示忙碌并禁用重复点击。
- 队列取消、路由异常、请求异常、dispose 后不留下忙碌状态或 timer。
- 屏幕熄灭暂停两种轮询，亮屏恢复；网络与前台事件仍通知两者。
- `removed_cidr` 的 eviction 日志与失败退避仍通过现有测试。

provider 测试使用 `ProviderContainer`、fake client、fake profile apply 与 `Completer`。若采用协调器，需要把现有 `_TestPo0Firewall.reapplyRouting` 与 `_TestGgyFirewall.reapplyRouting` 的测试接缝改为对共享协调器的应用接缝，不要继续期待各 scheduler 独立重载。

注意 `test/providers/po0_firewall_test.dart` 最后的「each switch drives only its own list」用例已被新需求取代，必须重写。保留 11 秒用例，并把 `_ggyOnly` 的启用字段改为 `enable: true`。

### 13.3 汇总模型

- 无条目、关闭、全部未返回、全部成功、部分成功、全部失败的状态分别正确。
- 一条成功、一条尚无结果，统计为 1/2。
- ggy 只有加白结果，没有完整白名单，也能统计成功。
- 删除条目后其旧结果不计入分母或成功数。
- 替换 token 后旧 token 的成功不归到新 token。
- 前 12 位相同的两个 token，各自结果仍准确匹配。
- 两个同名备注的条目不会互相覆盖。
- 重复有效条目与非法条目不会导致分母虚增。
- 改备注后结果卡片使用新备注。
- 服务出口不同或只是同一 /24 的不同表示时，不制造错误的共同出口。

### 13.4 页面交互

- 统一标题与导航名称正确，只有一个自动加白 Switch。
- 新增弹窗能选择两种类型，切换后输入标签、限制、校验同步。
- po0 输入 ggy 链接时报错；ggy 输入 po0 token 报错。
- ggy 必须是符合现有 `isGgyLink` 的完整 HTTPS 链接。
- 新增分别写入正确列表，备注 trim，凭据 trim。
- 重复新增被阻止；编辑原值不被误判重复。
- 新增时总开关关闭，仍保持关闭；已经开启时只由对应 scheduler 处理新增条目。
- 编辑 ggy 不覆盖 po0；删除混合列表的 ggy 不误删 po0。
- 只有 ggy 时不显示查询按钮；混合时查询只调用 po0 fake 的 `query`，不调用 ggy。
- 立即加白分别调用有条目的两个 fake；无条目的类型不调用。
- 总开关关闭或手动任务忙碌时按钮禁用。
- token 前缀相同、备注相同的列表仍可分别编辑删除。
- 列表、概览、结果、错误文本中没有完整凭据。
- 360～380 像素窄屏、约 820 像素宽屏不 overflow。

现有视图测试的 `_pump` 只返回 po0 fake；扩展为能拿到 po0 与 ggy 两个 fake。ggy fake 要增加 `whitelist` / `query` 调用计数，证明查询按钮没有误调用 ggy。

### 13.5 首页与导航

- 手机、窄桌面、宽桌面均只出现一个 `PageLabel.whitelist`。
- 不再包含 `PageLabel.po0`、`PageLabel.ggy`。
- 首页名称固定为加白，显示共享汇总。
- 同时有两种条目，推进 5 秒和 10 秒也不切换服务标题。
- 首页点击始终进入统一页面；只有 ggy、只有 po0、两者都没有时都一样。
- 侧栏副标题、首页、页面概览对同一组输入显示相同状态。
- dispose 后没有遗留轮换 timer。

### 13.6 传输与派生路由回归

- 运行现有 `test/common/po0_firewall_test.dart`，保证只读 po0、写入 ggy、认证 listener 和回落限制未变。
- 更新 `test/providers/state_derived_test.dart`，证明总开关开启排除 po0 地址，关闭不增加本功能的排除。
- 若调整了 profile 构造函数，增加或扩展 `test/providers/setup_action_test.dart`，证明总开关控制 listener 和 directCidrs。
- 四语言 ARB key 集一致，本地化 getter 生成正常，PageLabel exhaustive switch 编译通过。

测试不请求真实 ggy 链接，不查询真实用户 token。fake client 和纯汇总测试即可覆盖本次行为；UI 人工验收也优先使用受控配置与明确授权的测试条目。

## 14 代码生成与验证命令

Flutter 格式化、生成、分析、测试以构建 VPS 为约定环境，详见 `docs/development/build.md`。没有可用 VPS 连接信息时如实说明工具链限制，不能宣称已跑通，也不要自行寻找或使用陌生服务器。

根包 `dart run` 和 `flutter test` 都会触发原生 build hook。生成和测试可临时关闭 `build_assets`，但必须恢复并确认 diff。以下块仅用于文档约定的 Linux 构建 VPS，`sed -i` 写法不适用于 macOS：

```bash
set -euo pipefail
source /etc/profile.d/flclash-toolchain.sh
whitelist_pubspec_backup="$(mktemp)"
cp pubspec.yaml "$whitelist_pubspec_backup"
trap 'cp "$whitelist_pubspec_backup" pubspec.yaml; rm -f "$whitelist_pubspec_backup"' EXIT
sed -i 's/build_assets: true/build_assets: false/' pubspec.yaml

flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run intl_utils:generate

flutter test --reporter expanded \
  test/providers/config_test.dart \
  test/providers/po0_firewall_test.dart \
  test/models/whitelist_summary_test.dart \
  test/views/po0_firewall_view_test.dart \
  test/views/control_center_test.dart \
  test/providers/state_derived_test.dart \
  test/providers/setup_action_test.dart \
  test/common/po0_firewall_test.dart \
  test/widgets/views_smoke_test.dart \
  test/lint/dynamic_message_key_test.dart \
  test/l10n/app_localizations_test.dart
```

上述块应在独立 shell 中执行，让退出时的 trap 确实恢复文件。不要在临时关闭 native hooks 的状态提交或打包。

对实际修改的 Dart 源文件执行 `dart format`；新增文件也要包含。然后在恢复 `pubspec.yaml` 后运行：

```bash
bash scripts/vps/verify.sh --reporter expanded
git diff --check
git status --short
```

`scripts/vps/verify.sh` 包含 `flutter pub get`、格式检查、`flutter analyze --no-fatal-infos`、Flutter 测试与 75% 总覆盖率检查，并会自行临时关闭和恢复 native hooks。不要降低覆盖率门槛或删除行为测试来通过检查。

如果一个已存在的不相关失败确实阻止全量验证，明确给出失败文件、错误和本次聚焦测试结果，保留原门槛。不要把工具没运行、环境不可达或失败描述成通过。

源码扫尾搜索：

```bash
rg -n 'ggyEnable|PageLabel\.(po0|ggy)|Po0FirewallView|GgyFirewallView|whitelistPagesOf|WhitelistStatusCard\.rotation' lib test arb
rg -n 'po0 加白|ggy 加白|po0 防火墙加白|ggy 防火墙加白' arb lib/views lib/pages
rg -n 'build_assets:' pubspec.yaml
```

第一项 `ggyEnable` 只应出现在旧配置迁移和相应 raw JSON 测试中；不能再是模型字段、运行时开关、copyWith 参数或生成配置字段。第二项服务名可以用于必要的服务说明，但旧页面名称和旧导航名称不能继续使用。人工检查每个命中，不能用粗暴替换清空所有 po0 / ggy 文本。

## 15 仓库文档更新

实施时需要同步更新：

1. 新建 `docs/adr/0014-unified-whitelist.md`。创建前检查编号是否仍可用；如果已被占用，使用下一个空编号并同步引用。
2. ADR 写明：统一入口、一个总开关、旧开关 OR 迁移、混合 UI 与分开的持久化列表、各自调度节奏、查询仅 po0、共享路由协调。
3. `docs/adr/0013-ggy-page.md` 保留历史内容，把状态标为入口和独立开关部分被新 ADR 取代；固定 11 秒与服务差异仍有效。
4. `docs/adr/README.md` 添加新 ADR 索引并更新旧 ADR 状态。
5. `docs/features/po0-firewall.md` 改为统一加白页面说明，移除双页面、双开关和首页轮换介绍，增加总开关迁移规则。
6. `.agents/fork.md` 修订 `PageLabel.po0` 主入口和 ggy 独立页面、独立开关约束，保留 DIRECT 与 11 秒规则。
7. `docs/development/upstream-sync.md` 更新导航接线描述，以及新增的上游文件改动记录；已有记录也要与最终实现一致。
8. `docs/README.md` 的功能描述按需要改为 po0 / ggy 统一加白。

本指导文档记录的是目标实施方案。功能完成后，可以保留它作为实施记录，但用户功能说明与 `.agents` 规则必须描述最终实际行为，不能只在本文里写了新设计就让旧规则继续指导后续代理。

## 16 完成标准与交付说明

完成前逐项核对：

- [ ] 导航、标题、首页均只有一个加白入口。
- [ ] 一个真实配置总开关控制两种服务，无隐藏的第二开关。
- [ ] 旧开关 OR 迁移正确，关闭后保存重启仍关闭。
- [ ] 新增可以选择 po0 token / ggy 链接，数据写入正确列表。
- [ ] 原有条目、备注、po0 间隔、旧备份兼容保留。
- [ ] ggy 固定 11 秒，po0 先查询再按需补加。
- [ ] 查询按钮不触发 ggy 写入。
- [ ] 总开关变化通过共享协调器处理，快速切换以最新意图为准。
- [ ] 直连 listener、认证、路由排除与 ggy 不回落行为未受破坏。
- [ ] 汇总按有效当前条目统计，等待和陈旧结果不会产生虚假的全部成功。
- [ ] 首页轮换 timer 删除，空条目与 dispose 不留下调度 timer。
- [ ] 四语言文案和生成代码已更新，生成文件没有手改。
- [ ] 聚焦测试、全量校验和 diff 检查结果真实记录。
- [ ] `pubspec.yaml` 中原来的 `build_assets: true` 已恢复。
- [ ] ADR、用户功能文档和 agent 规则已同步。
- [ ] 未擅自改版本、发版、推送标签或增加无关改动。

交付说明应给出：具体改了哪些行为、旧配置如何迁移、跑过的验证命令与结果、任何尚未解决的环境限制。不要仅回复「已完成合并」；不要把仅重命名导航当作整个功能完成。

## 17 可直接交给实现代理的任务提示

```text
请实施 docs/development/whitelist-merge-guide.md 中的统一加白功能。

先读根 AGENTS.md 和指导文档第 2 节列出的约束，再检查当前 git 状态。
维护者已确认一个总开关，旧 enable 与 ggyEnable 任一个 true 就迁移为开启，
两者都 false 才关闭。不要再保留独立 ggy 开关。

按文档第 12 节的顺序直接实现，保留两个调度器和 ggy 固定 11 秒。
重点完成真实配置迁移、共享路由协调、混合条目新增与编辑删除、结果身份匹配、
统一导航和首页汇总；不要只改页面名称，也不要为了合并而破坏 DIRECT 传输。

模型、provider、本地化改动通过正式命令生成代码，禁止手改 generated 文件。
完成文档列出的聚焦测试与仓库要求的验证，更新 ADR、功能文档和 agent 规则。
不改版本号，不发版，不推送 release tag，不做无关重构。

遇到工具链或 VPS 不可用，记录真实限制，继续完成不受阻的实现和可运行验证。
结束时提供修改摘要、配置迁移说明和实际验证结果。
```
