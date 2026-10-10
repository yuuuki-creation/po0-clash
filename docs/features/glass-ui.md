# 液态玻璃界面

Android、Windows、macOS 共用一套苹果液态玻璃（Liquid Glass）风格的界面。操作结构见
[ADR 0009](../adr/0009-frosted-glass-ui.md)，视觉见 [ADR 0010](../adr/0010-liquid-glass.md)。

## 设计令牌（`lib/common/glass.dart`、`lib/common/app_theme.dart`）

| 令牌 | 浅色 | 深色（纯黑） | 用途 |
|---|---|---|---|
| `background` | `#F2F2F7` | `#1C1C1E`（`#000000`） | 窗口底色 |
| `card` | `#FFFFFF` | `#2C2C2E`（`#1C1C1E`） | 不透明的内容单元格 |
| `fill` | `#767680` 12% | `#767680` 24% | 分段轨道、输入框、次要按钮 |
| `thumb` | `#FFFFFF` | `#636366` | 分段控件的滑块 |
| `glass` / `glassStrong` | 白色半透明 | 深灰半透明 | 悬浮控件 / 弹窗与菜单 |
| `rimLight` / `rimShade` | — | — | 玻璃边缘的高光描边 |

- 强调色默认系统蓝，`seededColorScheme` 对默认色给出精确的 `#007AFF` / `#0A84FF`；其他颜色仍由种子生成。
- `ColorScheme.toGlass` 把表面色换成上表的中性色，Material 组件自然呈现苹果的分组列表样式。
- `GlassTone` 为苹果系统色：成功绿、警告橙、危险红、中性灰、靛蓝、青、粉；开关的开启色为系统绿。

## 组件（`lib/widgets/glass.dart`）

| 组件 | 用途 |
|---|---|
| `AppFloor` | 窗口底色；盖满窗口的推入页面自带一层 |
| `GlassSurface` | `tile` 为不透明单元格；`panel` 为悬浮玻璃；`chrome` 为会被内容滚过的玻璃，做模糊与饱和度增强 |
| `GlassButton` | 可点击的单元格或玻璃，点击区域与所画形状一致（圆形按钮只响应圆内） |
| `GlassSegmented` | 凹陷轨道与凸起滑块，整段高度都可点击 |
| `GlassIconBadge` | 设置行使用的 iOS 式纯色方块图标 |
| `GlassPill`、`GlassSectionLabel`、`GlassIconButton` | 状态胶囊、分组脚注、与视觉同尺寸的图标按钮 |

工具栏的操作按钮会合并到一个玻璃胶囊里（`CommonScaffold`）。胶囊统一排版：图标按钮与文字按钮都取平台图标按钮的高度
（Android 40、桌面 32），按钮间距 4。传给 `actions` 的按钮不要再套 `CommonMin*ButtonTheme`，也不要加 `SizedBox` 间隔。

## 操作结构（`lib/pages/home.dart`、`lib/pages/shell.dart`）

| 窗口宽度 | 布局 |
|---|---|
| < 600 dp | 页面铺满，底部悬浮玻璃底栏：主页、代理、配置、po0、ggy、设置；「活动」从设置或主页网速卡片进入 |
| 600～839 dp | 左侧玻璃侧边导航，页面直接放在底色上，包含主页和活动 |
| ≥ 840 dp | 左侧玻璃控制栏（连接按钮、出站模式、虚拟网卡 / 系统代理、各空间实时状态、网速与出口 IP），右侧为页面 |

- 控制中心：`lib/views/control/`。开关行为「虚拟网卡 | 系统代理 | 出口 IP」，Android 为「VPN | 出口 IP」；
  窄屏时隐藏调节按钮，长按开关打开选项。
- 桌面端虚拟网卡与系统代理二选一，见 [ADR 0011](../adr/0011-exclusive-desktop-route.md)。
- 活动：`lib/views/activity.dart`；设置：`lib/views/tools.dart`，iOS 设置式分组列表。

## 图标

源文件在 `assets_source/images/icon/`（应用图标、macOS 图标、Android 自适应图标前景 / 背景、TV 横幅、托盘图标），
运行 `bash tool/generate_app_icons.sh` 生成全部尺寸，需要 `rsvg-convert` 与 `cwebp`。

应用图标为扁平化的单一 P / 斜杠零组合符号，使用深墨绿 `#173529` 底色与薄荷绿 `#A5EDC6` 主体。
`po0_mark.svg` 为透明背景的独立标志；桌面、Android 自适应图标与托盘沿用相同轮廓，托盘保留原有状态配色。

## 测试

- `test/widgets/glass_test.dart`：分段控件整段可点、圆形按钮只响应圆内、图标按钮尺寸、配色。
- `test/widgets/toolbar_group_test.dart`：工具栏胶囊里文字按钮与图标按钮等高、居中对齐。
- `test/widgets/fade_box_test.dart`：`FadeScaleBox` 作为悬浮按钮时仍停在右下角。
- `test/pages/home_test.dart`：三种布局、侧边导航高亮与所选项对齐、底栏点击区域。
- `test/common/desktop_route_test.dart`、`test/views/control_center_test.dart`：二选一规则与开关行。
