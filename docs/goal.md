# 项目目标

## 背景

[po0fw](https://github.com/w0ven/po0fw) 通过定时向 po0 官方 IP 直连端点发起
`POST https://124.221.69.228/api/firewall/<token>/add`，把设备当前出口 IP 所在 /24 加入 po0 机器的防火墙白名单。
原项目以脚本 / 代理客户端模块的形式分发，需要用户在每台设备上单独部署。

## 目标

1. **集成**：内置 po0 与 ggy 自动加白，用户只需在应用里填入 token 或链接。
2. **常驻**：只要 po0-clash 处于打开状态——无论是否开启代理——都持续执行自动加白。
3. **正确性**：加白请求必须以真实出口 IP 发出，不能被本应用的代理 / TUN 劫持成代理节点的 IP。
4. **原生应用**：macOS 用 SwiftUI，Windows 用 Tauri，Android 用 Jetpack Compose；三端共享一个精简的 Rust 内核，
   代理引擎为原版 mihomo（[ADR 0018](adr/0018-native-rewrite.md)）。
5. **精简**：只提供[功能范围](development/native-rewrite.md#功能范围)里列出的功能；界面按各平台规范从零设计，不沿用旧版。
6. **交付**：
   - Windows：Tauri 打包的安装程序，自签名。
   - macOS：终端命令一键安装。
   - Android：APK 安装包。
   - iOS、Linux：不做。
7. **独立应用**：以 po0-clash 的身份发布，应用 ID、安装标识、进程 / 服务名、数据目录与官方 FlClash 完全不同，
   两者可在同一设备上同时安装、运行；版本号独立（[ADR 0006](adr/0006-standalone-app-identity.md)）。
8. **工程化**：代码放在独立的 GitHub 仓库，及时推送；仓库包含 `AGENTS.md` 与 `docs/` 等标准流程结构；编译和测试在构建机
   与 GitHub Actions 上进行，不在本机；全部平台的发版产物由 GitHub Actions 在推送版本标签后构建。

## 非目标

- 不修改 mihomo。
- 不引入自建服务端；加白只调用 po0 官方端点。
- 不设内存上限，也不做常驻内存调优。
- 不追求三端界面一致，也不复刻 Flutter 版的界面和功能。

## 过渡

维护中的 Flutter 版（6.x）只修严重问题。各平台的原生版达到功能范围后，以同一应用 ID 覆盖升级，替换该平台的 Flutter 版。
