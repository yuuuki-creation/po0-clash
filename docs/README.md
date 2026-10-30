# po0-clash 文档

本仓库是 [chen08209/FlClash](https://github.com/chen08209/FlClash) 的二次开发版本，在原版基础上内置
[po0fw](https://github.com/w0ven/po0fw) 的 po0 防火墙自动加白，各平台统一使用由 Material 组件实现的简洁界面。
po0-clash 以独立应用的身份发布，可与官方 FlClash 同时安装（见 [ADR 0006](adr/0006-standalone-app-identity.md)）。

正在按 [ADR 0018](adr/0018-native-rewrite.md) 重写为三端原生应用，共享一个精简的 Rust 内核，方案见
[development/native-rewrite.md](development/native-rewrite.md)。现有的 Flutter 版进入维护期，只修严重问题。

上游自带的开发规范（代码风格、测试、生成代码、提交规范）仍然有效，见根目录 [AGENTS.md](../AGENTS.md) 与 [.agents/](../.agents/)。
本目录只记录**本分支特有**的内容。

## 目录

| 文档 | 内容 |
|---|---|
| [goal.md](goal.md) | 项目目标与交付范围 |
| [install.md](install.md) | 用户安装说明（Windows 安装包 / macOS 终端安装 / Android APK） |
| [features/po0-firewall.md](features/po0-firewall.md) | 加白（po0 / ggy 自动加白）：统一入口、总开关迁移、行为与直连路由设计 |
| [features/share-link-nodes.md](features/share-link-nodes.md) | 分享链接导入节点：「手动节点」配置、模板生成、节点管理 |
| [features/glass-ui.md](features/glass-ui.md) | 统一简洁界面：表面、导航、按需刷新与图标 |
| [development/build.md](development/build.md) | 构建：VPS（校验）、GitHub Actions（Android / Windows / macOS 发版）、签名、本地开发 |
| [development/release.md](development/release.md) | 发版流程、版本号与产物命名 |
| [development/upstream-sync.md](development/upstream-sync.md) | 如何合并上游 FlClash 更新 |
| [development/native-rewrite.md](development/native-rewrite.md) | 三端原生重写：结构、共享内核、功能范围、界面与顺序 |
| [development/native-feature-parity.md](development/native-feature-parity.md) | 原生版对齐 FlClash 的逐项功能清单与顺序 |
| [development/native-design.md](development/native-design.md) | 原生版视觉规范：颜色、文字、尺寸、组件与页面 |
| [development/native-macos.md](development/native-macos.md) | macOS 原生版：结构、数据迁移、虚拟网卡授权、构建与测试 |
| [development/native-windows.md](development/native-windows.md) | Windows 原生版（Tauri）：安装与升级、构建、虚拟机测试 |
| [adr/](adr/) | 架构决策记录（ADR） |

## 工作流约定

1. 需求先落到 [goal.md](goal.md) 或新的 ADR，再动代码。
2. 功能在 `feat/*` 分支开发，提交遵循上游的 Conventional Commits 规则（`tool/check_commit_msg.sh`）。
3. 合入 `main` 前在构建机上跑通 `flutter analyze`、`flutter test` 与覆盖率门槛（见 [development/build.md](development/build.md)）。
4. 仅在维护者明确要求时发版：打 `v<X.Y.Z>` 标签（与 `pubspec.yaml` 版本一致），由 GitHub Actions 构建全部平台并挂到
   GitHub Release（见 [development/release.md](development/release.md)）。
