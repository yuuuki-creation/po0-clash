# 原生版界面重设计

本页记录 7.x 的设计。8.1.0 起的界面基准见 [ADR 0022](../../adr/0022-native-ui-upstream-alignment.md)。

决定见 [ADR 0021](../../adr/0021-native-ui-traditional.md)。三端共享同一个 Rust 内核（`crates/core` 与 `crates/ffi`），界面层完全采用各操作系统的原生控件体系与平台设计语言，不再使用跨端统一的 Web 风格手绘控件。

## 平台原生架构与设计准则

| 平台 | 技术栈 | 设计准则与原生控件 |
|---|---|---|
| **macOS** (`apps/macos`) | SwiftUI + AppKit | 遵循 Apple Human Interface Guidelines（System Settings 风格）：使用原生 `Toggle(.switch)`、`Picker(.segmented)`、双箭头 `NSPopUpButton` 选择器、动态 `NSColor` 语义色板（`windowBackgroundColor` / `controlBackgroundColor` / `separatorColor` / `controlAccentColor`）、`13pt` 标准正文字号与强调色半透明侧栏选中态。 |
| **Android** (`apps/android`) | Jetpack Compose (`androidx.compose.material3`) | 遵循 Material Design 3：使用官方 `NavigationBar` + `NavigationBarItem`、`NavigationRail` + `NavigationRailItem`、`Switch`（`52×32dp`）、`RadioButton`、`SingleChoiceSegmentedButtonRow` + `SegmentedButton`、`Button`、`FloatingActionButton`、`FilterChip` 与完整的 M3 `ColorScheme` 色调表面层级。 |
| **Windows** (`apps/windows`) | Tauri v2 + Win32/DWM + WinUI 3 (Fluent 2) | 遵循 Windows 11 WinUI 3 / Fluent 2：主窗口启用 `DWMWA_SYSTEMBACKDROP_TYPE`（Mica `#F3F3F3` / `#202020`）与 `DWMWCP_ROUND` 原生圆角阴影，系统托盘采用 `uxtheme` 原生弹出菜单；控件遵循 `4px` 控件圆角 / `8px` 卡片圆角、`NavigationView` 左侧 `3px × 16px` 竖向强调色指示条、`40×20px` `ToggleSwitch`、`ControlElevationBorderBrush` 立体按钮边框与底部 `2px` 焦点下划线输入框。 |

- 所有速度、流量、延迟、端口数字统一启用 `tabular-nums` 等宽数字，操作按钮（连接、测速、立即检查）在忙碌态预留固定宽度，杜绝布局抖动。
- 自包含的指标面板（KPI 卡片、实时流量图、顶部连接状态卡）使用平台原生卡片容器；集合列表与设置项使用带 `1px` 分割线的分组行容器（macOS `InsetGrouped`、Windows `SettingsExpander` 卡片行、Android M3 `SurfaceContainerLow` 分组卡片）。

## 各端语义色板与表面层级

### 1. macOS（AppKit 动态 `NSColor`）

| 用途 | 浅色 (`aqua`) | 深色 (`darkAqua`) |
|---|---|---|
| 窗口与侧栏底 (`NSColor.windowBackgroundColor`) | `#F5F5F7` | `#1E1E1E` |
| 分组卡片底 (`NSColor.controlBackgroundColor`) | `#FFFFFF` | `#262629` |
| 浮层 / 面板 (`NSColor.underPageBackgroundColor`) | `#FFFFFF` | `#2C2C2E` |
| 分割线与卡片描边 (`NSColor.separatorColor`) | `rgba(0, 0, 0, 0.09)` | `rgba(255, 255, 255, 0.10)` |
| 强调色 (`NSColor.controlAccentColor`) | `#007AFF`（跟随系统强调色） | `#0A84FF`（跟随系统强调色） |

### 2. Android（Material 3 `ColorScheme`）

| 用途（M3 Role） | 浅色 | 深色 |
|---|---|---|
| 页面背景 (`background` / `surface`) | `#F8F9FF` | `#111318` |
| 分组卡片表面 (`surfaceContainerLow` / `surfaceVariant`) | `#FFFFFF` / `#E0E2EC` | `#1D2024` / `#43474E` |
| 导航栏与模态表面 (`surfaceContainer`) | `#ECEEF4` | `#282A2F` |
| 主强调色 (`primary` / `onPrimary`) | `#0061A4` / `#FFFFFF` | `#9ECAFF` / `#003258` |
| 选中胶囊容器 (`secondaryContainer` / `onSecondaryContainer`) | `#D3E4FF` / `#001C38` | `#00497D` / `#D1E4FF` |
| 描边与分割线 (`outline` / `outlineVariant`) | `#73777F` / `#C3C6CF` | `#8D9199` / `#43474E` |

### 3. Windows（WinUI 3 / Fluent 2 Token）

| 用途（WinUI 3 Brush） | 浅色 | 深色 |
|---|---|---|
| 窗口 Mica 基底 (`ApplicationPageBackgroundThemeBrush`) | `#F3F3F3` | `#202020` |
| 内容表面 (`LayerFillColorAltBrush`) | `#F9F9F9` | `#272727` |
| 卡片表面 (`CardBackgroundFillColorDefaultBrush`) | `#FFFFFF` | `#2B2B2B` |
| 浮层 / 菜单 (`AcrylicBackgroundFillColorBaseBrush`) | `#FCFCFC` | `#2C2C2C` |
| 卡片描边 (`CardStrokeColorDefaultBrush`) | `rgba(0, 0, 0, 0.06)` | `rgba(255, 255, 255, 0.08)` |
| 按钮立体边框 (`ControlElevationBorderBrush`) | `rgba(0, 0, 0, 0.06)`（底边 `0.16`） | `rgba(255, 255, 255, 0.09)`（顶边 `0.14`） |
| 系统强调色 (`SystemAccentColor`) | `#0067C0`（跟随 DWM 注册表） | `#60CDFF`（跟随 DWM 注册表） |

## 圆角与尺寸规范

| 平台 | 内部徽章 | 常规控件（按钮/输入/菜单项） | 卡片与分组容器 | 对话框 / 底部面板 | 控件标准高度 |
|---|---|---|---|---|---|
| **macOS** | `4pt` | `6pt` | `10pt` | `12pt` | 紧凑 `24pt`、标准 `28pt`、侧栏行 `30pt` |
| **Android** | `8dp` | `12dp`（按钮与开关为全胶囊 `9999dp`） | `16dp` | `28dp` | 按钮 `40dp`、筛选 Chip `32dp`、触控列表行 `48–56dp` |
| **Windows** | `4px` | `4px` | `8px` | `8px` | 紧凑 `28px`、标准按钮/输入 `32px`、导航项 `36px` |

## 窗口拉伸与自适应断点

| 平台 | 导航栏断点 | 内容区布局 |
|---|---|---|
| **Windows**（最小 `720×560`） | `>= 1008px` 显示完整 `NavigationView` 侧栏；更窄时收起为图标栏，汉堡按钮展开浮层 | 宽度不足 `700px` 时双栏合一 |
| **macOS**（最小 `620×480`） | `>= 760pt` 显示常驻侧边栏；更窄时收起，工具栏按钮展开覆盖层 | 同上 |
| **Android** | `< 600dp` 使用底部 `NavigationBar`；`>= 600dp` 使用左侧 `NavigationRail` | `>= 840dp` 时代理页左右分栏，卡片双列网格 |

- 桌面端内容区不足 `700` 时：节点组列表切换为下拉选择器，表格依次隐藏类型、规则、Token 和到期列。
- 窗口很大时：仪表盘、配置、加白和工具最大内容宽度 `1100`，代理和活动页铺满。

## 动画与动态效果

单位是 ms，“开 / 关”表示打开和关闭。

| 操作 | Windows (Fluent 2) | macOS (HIG) | Android (Material 3) |
|---|---|---|---|
| 切换页面 | 上滑淡入 `167` | 无 | 淡入微缩放 `300` |
| 导航选中 | 竖条缩放滑动 `167` | 无 | 胶囊指示器展开 `300` |
| 分段控件 | 滑块 `167` | 原生 `NSSegmentedControl` | `SegmentedButton` 对勾展开 `150` |
| 开关 | 原生 `ToggleSwitch` `167` | 原生 `NSSwitch` `200` | 原生 M3 `Switch` `200` |
| 对话框开 / 关 | `167 / 83` | `200 / 150` | `300 / 150` |

- 三端均跟随系统“减少动态效果”（macOS `accessibilityReduceMotion`、Windows `UISettings.AnimationsEnabled`、Android `ANIMATOR_DURATION_SCALE`）；应用内“页面切换动画”开关仅控制切页过渡。
- 搜索过滤与实时流量/延迟数字直接更新，不套缓动动画。

## 连接按钮与节点组交互

- **连接按钮**：三端均置于仪表盘顶部状态卡右侧；已连接为次要按钮样式“断开连接”，未连接为主强调色按钮“连接”，切换中禁用并显示旋转指示器，固定最小宽度防止跳动。Android 悬浮操作按钮（`FloatingActionButton`）仅用于配置页和加白页的“添加”。
- **节点组与节点列表**：
  - 桌面宽窗口：左侧 `230px` 组列表（显示组名与当前选中节点），右侧节点表格或卡片网格。
  - Android 手机：顶部横向滚动 `FilterChip` 胶囊栏（可切换为分组折叠列表），下方直接展示节点行或双列卡片。
  - 搜索框同时匹配组名和节点名；支持默认、按延迟、按名称排序；`selectable == false` 的策略组（`URLTest`、`Fallback`）仅展示当前自动选中的节点。
  - 全量测速按最多 4 组并发分批执行，避免阻塞内核控制器。
