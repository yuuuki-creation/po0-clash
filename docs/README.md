# po0-clash 文档

本仓库是 [chen08209/FlClash](https://github.com/chen08209/FlClash) 的二次开发版本，在原版基础上内置
[po0fw](https://github.com/w0ven/po0fw) 的 po0 防火墙自动加白，三端统一使用苹果液态玻璃风格的界面。
po0-clash 以独立应用的身份发布，可与官方 FlClash 同时安装（见 [ADR 0006](adr/0006-standalone-app-identity.md)）。

上游自带的开发规范（代码风格、测试、生成代码、提交规范）仍然有效，见根目录 [AGENTS.md](../AGENTS.md) 与 [.agents/](../.agents/)。
本目录只记录**本分支特有**的内容。

## 目录

| 文档 | 内容 |
|---|---|
| [goal.md](goal.md) | 项目目标与交付范围 |
| [install.md](install.md) | 用户安装说明（Windows 安装包 / macOS 终端安装 / Android APK） |
| [features/po0-firewall.md](features/po0-firewall.md) | 加白（po0 / ggy 自动加白）：统一入口、总开关迁移、行为与直连路由设计 |
| [features/glass-ui.md](features/glass-ui.md) | 三端统一的液态玻璃界面：设计令牌、玻璃组件、操作结构与图标 |
| [development/build.md](development/build.md) | 构建：VPS（校验）、GitHub Actions（Android / Windows / macOS 发版）、签名、本地开发 |
| [development/release.md](development/release.md) | 发版流程、版本号与产物命名 |
| [development/upstream-sync.md](development/upstream-sync.md) | 如何合并上游 FlClash 更新 |
| [adr/](adr/) | 架构决策记录（ADR） |

## 工作流约定

1. 需求先落到 [goal.md](goal.md) 或新的 ADR，再动代码。
2. 功能在 `feat/*` 分支开发，提交遵循上游的 Conventional Commits 规则（`tool/check_commit_msg.sh`）。
3. 合入 `main` 前在构建机上跑通 `flutter analyze`、`flutter test` 与覆盖率门槛（见 [development/build.md](development/build.md)）。
4. 仅在维护者明确要求时发版：打 `v<X.Y.Z>` 标签（与 `pubspec.yaml` 版本一致），由 GitHub Actions 构建全部平台并挂到
   GitHub Release（见 [development/release.md](development/release.md)）。
