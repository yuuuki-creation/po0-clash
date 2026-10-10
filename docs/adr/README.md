# 架构决策记录（ADR）

每个影响架构、构建或交付方式的决定写一篇 ADR，文件名 `NNNN-短标题.md`，编号递增、不复用。
已被取代的 ADR 不删除，把状态改为「已取代（见 NNNN）」。

模板：

```markdown
# NNNN. 标题

- 状态：提议 / 已采纳 / 已取代（见 NNNN）
- 日期：YYYY-MM-DD

## 背景
## 决定
## 后果
```

| 编号 | 标题 | 状态 |
|---|---|---|
| [0001](0001-direct-routing-for-po0-api.md) | po0 API 请求的直连路由 | 已采纳 |
| [0002](0002-build-infrastructure.md) | 构建基础设施：VPS + GitHub Actions | 已采纳，Android 构建与签名部分已取代（见 0006） |
| [0003](0003-heroui-desktop-theme.md) | 桌面端 HeroUI 风格主题 | 已取代（见 0008） |
| [0004](0004-per-second-read-only-polling.md) | 每秒只读轮询白名单 | 已采纳，固定槽位部分已取代（见 0007） |
| [0005](0005-token-list-and-poll-interval.md) | token 列表与可调刷新间隔 | 已采纳，固定槽位部分已取代（见 0007） |
| [0006](0006-standalone-app-identity.md) | po0-clash 作为独立应用发布 | 已采纳 |
| [0007](0007-remove-fixed-slots.md) | 去掉固定槽位 | 已采纳 |
| [0008](0008-material3-on-every-platform.md) | 三端统一使用 Material 3 | 已取代（见 0009） |
| [0009](0009-frosted-glass-ui.md) | 磨砂玻璃界面与新的操作结构 | 已采纳，视觉部分已取代（见 0010） |
| [0010](0010-liquid-glass.md) | 改为苹果液态玻璃风格 | 已采纳 |
| [0011](0011-exclusive-desktop-route.md) | 桌面端虚拟网卡与系统代理二选一 | 已采纳 |
| [0012](0012-direct-listener-and-ggy.md) | 内核专用直连入口与 ggy 加白链接 | 已采纳，ggy 入口与轮询部分已取代（见 0013） |
| [0013](0013-ggy-page.md) | ggy 作为独立页面，固定 11 秒轮询 | 已采纳，独立页面与独立开关部分已取代（见 0014） |
| [0014](0014-unified-whitelist.md) | po0 与 ggy 合并为统一加白入口 | 已采纳 |
