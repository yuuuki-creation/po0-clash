# 0012. 内核专用直连入口与 ggy 加白链接

- 状态：已采纳
- 日期：2026-10-03

## 背景

ggy（guguyun.com）是 po0 的下游，同样按请求来源 /24 加白，但给用户的是一条完整链接
`https://www.guguyun.com/…/firewall/whitelist?token=ctecsfw_…`。实测（2026-10-03）：

- 对这条链接发一次 GET 就会加白，返回 `{"status":200,"msg":…,"data":{"cidr":"x.x.x.0/24","mode":"fifo","slot":null,"removed_cidr":""}}`。
  `removed_cidr` 是 FIFO 为腾出位置挤掉的记录。没有找到只读查询接口，返回里也没有完整白名单和上限。
- 它是域名，前面是雷池 WAF，按地区解析到至少 4 个不同 IP。

ADR 0001 的三层（DIRECT `HttpClient`、`IP-CIDR` DIRECT 规则加 `route-exclude-address`、Android VPN 路由拆分）
都以固定 IP 为前提：全局模式下 mihomo 不看规则，只能靠路由排除；而域名先被解析成 fake-ip，拿不到真实 IP 去排除。
固定几个 IP 也不可靠，地区线路会变。

## 决定

- 功能开启时，生成配置强制加入一个 listener：`{name: po0-direct, type: http, listen: 127.0.0.1, port: <动态>, proxy: DIRECT}`
  （`withPo0DirectListener`，在 `setup.dart` 里于覆写脚本之后注入，订阅里有同名 listener 时替换）。
  mihomo 在 `tunnel.resolveMetadata` 里先看入站指定的 `proxy`，再看模式，所以规则、全局模式和 TUN 都改变不了它的去向；
  DIRECT 出站由内核自己解析域名，并从物理网卡发出（桌面端绑定物理网卡，Android 端 `protect`）。
  listener 带一组每次会话随机生成的 `users`（与应用的入站认证无关）。否则本机任何程序都能借它绕过规则、VPN 和全局模式，
  从真实 IP 直连出去；Android 上所有应用共用回环地址，这一点尤其重要。
- 端口不写死：每次应用会话第一次需要时，由系统在 127.0.0.1 上分配一个空闲端口（`ServerSocket.bind(…, 0)` 后立即释放），
  本次会话内生成配置和发请求都用它和同一组账号（`po0DirectListener.endpoint`，缓存的是 Future，两处同时首次取值也只探测一次）。
  会话内不重新探测：内核一旦按配置占住这个端口，再探测必然显示被占，只会让 listener 在每次应用配置时换一次端口。
  探测失败时只是不注入 listener 并写一条警告，不影响配置的其余部分。
- 加白请求的出口：代理运行且未被 SSID 暂停时走 `PROXY <账号>@127.0.0.1:<端口>`（`po0ListenerRoute`），否则 DIRECT
  （Android 上暂停会连同 VPN 一起停掉）。出口变化时丢弃复用的连接。po0 与 ggy 都走这条路径。
- 只有 po0 可以回落：po0 的地址同时被 ADR 0001 排除出 TUN，所以对它写成 `PROXY …; DIRECT`，listener 连不上
  （没选配置、端口被抢等）时退回普通直连，行为与以前相同。ggy 不回落，listener 连不上时请求直接失败：
  回落会让请求被 TUN 接管，把代理节点加白，还会按 FIFO 挤掉一条真实记录。
- 限流（HTTP 429）按临时失败处理，调度器随之退避，不会在被限流时继续按间隔请求。
- ggy 链接作为一项 token 保存在 `Po0TokenEntry.token` 里（整条链接），类型由内容推断（`Po0Token.kind`），
  不改持久化格式。界面上在添加 token 的对话框第一栏选择「po0」或「ggy 加白链接」。
- ggy 没有只读形式，调度器不为它特殊处理：轮询、「查询状态」、「立即加白」都直接请求加白链接，默认每 5 秒一次。
  维护者确认可以接受（2026-10-03）：那次实测的 `removed_cidr` 为空，网段已在名单中时服务端大概率幂等。
  加白挤掉记录（`removed_cidr` 非空）时总会写日志，用来发现服务端并不幂等的情况。

## 后果

- 代理运行时，po0 的请求也不再依赖路由排除，Android 开启功能后不必重启 VPN。
- 刚启动代理、listener 还没起来的那一刻请求会失败一次，由下一轮重试。
- 端口在探测时一定空闲。从释放到内核绑定之间有极短的窗口，如果端口恰好在这时被别的程序占走，listener 起不来
  （内核日志里有报错）：po0 退回普通直连，ggy 在本次会话内代理运行期间会一直失败，重启应用后换新端口。
- Android 上 VPN 可以比界面进程活得久：界面重启后会探测新端口，启动时重新应用配置，listener 随之换到新端口。
- ggy 被其它设备挤出后，和 po0 一样在一个刷新间隔内补回。
- 如果 ggy 对已在名单中的网段并不幂等，每次请求都会挤掉一条记录，日志会持续出现 `evicted`。
  这时应改回只在网络变化时请求，或者向 ggy 要只读接口。刷新间隔调得很短（最低 1 秒）时，也可能触发 ggy 的 WAF 限流。
