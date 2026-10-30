# 0020. 原生版功能对齐 FlClash

- 状态：已采纳
- 日期：2026-10-30

## 背景

ADR 0018 把原生版的功能精简到 [goal.md](../goal.md) 的最小集合。维护者改变了决定：功能不再精简，FlClash（以及本 fork）
有的，原生版都要有。

## 决定

- 原生版的功能范围是 Flutter 版的全部功能，清单与顺序见
  [development/native-feature-parity.md](../development/native-feature-parity.md)。
- 架构不变：功能仍由共享的 Rust 内核实现，原版 mihomo 通过 external-controller 控制，三端界面只做展示与操作。
- 导航与 Flutter 版一致：仪表盘、代理、配置、加白、活动、工具。
- 没有例外。主题色照 Flutter 版提供（预设是苹果的系统色，默认系统蓝，可加自定义色），只改强调色，背景仍是中性色；崩溃上报
  对应 Flutter 版本地的启动崩溃保护，不接任何第三方服务（ADR 0006）。

## 后果

- 取代 ADR 0018 中「功能只保留最小集合」与「不做」清单、`docs/development/native-rewrite.md` 的「功能范围」，以及
  ADR 0019 中仪表盘「仍然不做流量图表、连接列表和日志页」与「系统蓝作强调色」两处：强调色默认系统蓝，可在外观里换。
- 原生版替换 Flutter 版的时间推后：某个平台要等清单上的功能在该平台都完成，才以同一应用 ID 覆盖升级。
