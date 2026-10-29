# 0018. 三端原生重写，共享精简的 Rust 内核

- 状态：已采纳
- 日期：2026-10-29

## 背景

ADR 0017 计划保留 Flutter 界面，把应用逻辑逐步迁到 Rust。维护者随后改了方向：三端界面都换成各自平台的原生框架，
各自从零设计，不受 Flutter 版影响；功能和后台一起精简，越简洁越好；三端都不再设内存上限。

## 决定

- 三个原生应用：macOS 用 SwiftUI，Windows 用 Tauri 2，Android 用 Kotlin + Jetpack Compose。
- 三端共享一个精简的 Rust 内核，负责设置、订阅、配置生成、加白和代理引擎控制。Swift 与 Kotlin 经 UniFFI 调用，Tauri 直接链接。
- 代理引擎用原版 mihomo，固定版本、不打补丁，通过它自带的 external-controller 控制。不再维护 FlClash 的 Go 包装层和
  自定义 IPC 协议；Android 上只保留一层很薄的 JNI，负责传入配置和 TUN 描述符、启动与停止。
- 功能只保留 [goal.md](../goal.md) 列出的最小集合；界面按各平台规范单独设计，不追求三端一致。
- 不设内存上限，也不做常驻内存调优。
- Flutter 版（6.x）进入维护期，只修严重问题。某个平台的原生版达到功能范围后，以同一应用 ID 覆盖升级，替换该平台的 Flutter 版。
- 结构、顺序和测试方式见 [development/native-rewrite.md](../development/native-rewrite.md)。

## 后果

- 本 ADR 取代 ADR 0017；ADR 0016 的界面规定只适用于维护中的 Flutter 版。
- ADR 0001、0006、0011、0012 在新应用里继续有效：加白请求走物理出口，应用身份与 FlClash 隔离，桌面端虚拟网卡与系统代理
  二选一，内核运行时加白请求走 `po0-direct` 入口。
- 不再与上游 FlClash 同步。
- 匿名约束不变：不申请实名的苹果开发者账号，所以 macOS 不用 Network Extension、不做公证，TUN 继续靠 setuid root 的
  内核；Windows 继续自签名。
