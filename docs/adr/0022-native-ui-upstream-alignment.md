# 0022. Android 界面对齐当前 FlClash，桌面界面对齐 Clash Verge Rev

- 状态：已采纳，8.1.0 起
- 日期：2026-11-12

8.0.0 的 Android 界面参考 FlClash 0.8.92，与当前稳定版已有差异。维护者要求更新 Android 界面，并补齐 Windows、macOS 与 Clash Verge Rev 的差距。

- Android 保留 Compose 与共享 Rust 内核，界面基准为 [FlClash 0.9.3](https://github.com/chen08209/FlClash/tree/v0.9.3)。仪表盘采用纵向卡片，启动操作在顶部状态卡内，代理组使用胶囊标签。连接卡片不能隐藏，其余卡片保留用户设置。
- Windows 和 macOS 共用 React / MUI 界面，基准为 [Clash Verge Rev 2.5.10](https://github.com/clash-verge-rev/clash-verge-rev/tree/v2.5.10)。补齐首页卡片设置、窗口缩放与键盘操作；保留 po0 的应用身份和加白入口。
- 桌面首页的 `homeCards` 与 Android 的 `dashboardCards` 分开保存，经 Rust 内核持久化。新增字段不改变旧设置文件的其它选项。
- 发版前检查实际应用与截图。浏览器模拟检查覆盖两种桌面外观和渲染引擎，不能替代原生壳与 VPN 的验证。

本决定替代 ADR 0019、0021 的界面样式规定。代理、VPN、加白的运行和生命周期约束不变。
