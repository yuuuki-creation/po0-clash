# 常驻内存验证

三端已不再设内存目标（[ADR 0018](../adr/0018-native-rewrite.md)）。本文只保留 Flutter 版的测量方法和历史数据。

## NL 采样

2026-10-25 在 API 35 x86_64 Android 模拟器中使用 release 引擎、固定 DIRECT 测试配置和 mixed 协议栈。
启动 VPN 后返回桌面，等待回收完成，再按 10 秒间隔采样。Android 的 PSS 已包含同进程 Core；多进程时脚本会累加。

| 环境 | 基线 PSS | 当前候选 PSS | 交换内存 |
|---|---:|---:|---:|
| Android，后台、VPN 运行 | 约 170 MB | 约 116 MB | 0 |
| Linux，无头 OpenGL，UI 与 Core 合计 | 约 347 MB | 约 281 MB | 0 |

这是固定测试配置下的进程采样，不能代表复杂订阅、真实流量负载或所有设备。Linux 图形驱动占用计入合计，
这组结果也不能代替 Windows / macOS 原生测量。切换 Android 图形后端没有额外收益，未修改默认后端。

```bash
python3 tool/measure_resident_memory.py --package io.github.yuuukicreation.po0clash \
  --serial emulator-5556 --samples 12 --interval 10 --settle 30 --output android-memory.json
python3 tool/measure_resident_memory.py --pid "$ui_pid" --pid "$core_pid" \
  --samples 12 --interval 10 --settle 30 --output desktop-memory.json
```

原始报告在 NL 隔离工作区的 `.validation/`，包括 `android-memory-ui-cache.json`、`android-memory-skia.json`、
`desktop-memory-candidate.json`、`memory-socks-takeover.txt` 和 `memory-resume-cycles.log`。

## 回收边界

UI 可见性仅控制缓存预算和延迟回收，不改变代理、Core 进程租约或加白调度。恢复前台会取消尚未开始的回收，
并恢复 8 MiB 图形缓存预算。图像缓存限制为 8 MiB / 128 项，SVG 缓存限制为 32 项；后台释放可重建缓存。

Go 的默认软预算为 32 MiB、GOGC 为 50，显式环境变量优先。软预算只约束 Go 运行时，不能用作进程内存达标证明。
后台 GC 归还闲置 Go 页，平台分配器仅释放未使用的堆空间。

Android / Linux 另回收自身库的干净文件映射页。必须同时确认私有、只读、无脏页、无匿名页、无交换页；
不能仅按只读权限回收 RELRO，因为其中可能有重定位指针。Android UI 库先用 `RTLD_NOLOAD` 增加引用，扫描结束后释放，
避免引擎销毁和地址重用发生竞争；不回收未知映射。内核按原文件重新调页，不丢弃活动堆或连接状态。

回归覆盖独立 UID 的 VPN 接管、VPN 已运行时的 Core TCP / SOCKS UDP 回收，以及五轮 UI 恢复和后台回收后保持同一 TCP 连接。
当前 Go 测试、race、vet 及 Windows / Darwin Core 交叉编译通过；Flutter 2088 项通过、3 项跳过，原生 JVM 122 项通过。
内存回收 Cgo 文件的编译约束和 C 编译前导必须使用注释语法，按仓库允许的例外单文件放宽注释密度门槛。
