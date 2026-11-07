本版重新设计并实现了三端原生界面（macOS 26 原生 Liquid Glass 液态玻璃与 Bento 仪表盘、Android Material 3 Expressive 卡片网格、Windows 11 WinUI 3 Fluent 2 Bento 卡片网格），并修复部分交互细节。
从 7.0.0、7.1.0、7.1.1、7.2.0 或 Flutter 版都可以直接覆盖升级。

## 安装

### macOS（13 及以上，Apple 芯片与 Intel 通用）

在终端运行：

```bash
curl -fsSL https://github.com/yuuuki-creation/po0-clash/releases/download/native-v7.3.0/install-macos-native.sh | bash
```

脚本会退出并替换已安装的 po0-clash（包括 Flutter 版），装到「应用程序」后启动。应用没有经过苹果公证，脚本会去掉下载带来的隔离标记。
第一次切到「虚拟网卡」时需要输入一次管理员密码，用来安装以 root 运行的内核；取消则继续使用系统代理。

### Windows（10 / 11，x64）

在 PowerShell 里运行：

```powershell
irm https://github.com/yuuuki-creation/po0-clash/releases/download/native-v7.3.0/install-windows-native.ps1 | iex
```

脚本会下载安装程序、校验 SHA-256、请求一次管理员权限，装好后打开应用。这样下载的文件没有网络来源标记，不会触发 SmartScreen 提示。

也可以下载 `po0-clash-7.3.0-windows-x64-setup.exe` 手动运行。安装程序没有签名，SmartScreen 拦下时点「更多信息」→「仍要运行」。

**智能应用控制：** 这个功能开着时，未受信任签名的应用可能仍被拦截，命令安装也不一定能绕开，微软也不提供单个应用的例外。被拦时要在「Windows 安全中心 → 应用和浏览器控制 → 智能应用控制设置」里关闭它。

应用以管理员身份运行（虚拟网卡需要）。已装 Flutter 版时会先静默卸载它，订阅和加白条目保留并导入。

### Android（8.0 及以上）

按手机的处理器选 APK：绝大多数手机用 `arm64-v8a`，较老的 32 位手机用 `armeabi-v7a`，模拟器用 `x86_64`。

可以直接覆盖安装 Flutter 版，订阅和加白条目会自动导入。覆盖之后不能直接装回 Flutter 版，要先卸载，应用数据会一起清除。

## 功能

- 仪表盘：网络速度曲线、流量与连接数、内存、出口 IP、内网 IP、订阅用量、加白，卡片可增删排序。
- 代理：标签式或列表式，排序、定位当前节点、单节点与整组测速。
- 配置：订阅、文件导入、分享链接导入（节点可改名、删除），编辑原文、预览最终配置、导出、排序；覆写分标准（追加规则、停用全局规则、
  MATCH 目标）、脚本（JavaScript）和自定义三种。
- 活动：实时请求、当前连接（可断开）、日志（筛选、导出）。
- 工具：基础配置、网络、DNS、高级（全局追加规则、脚本库）、Geo 资源与代理集 / 规则集、规则、外观（主题色）、语言、应用设置、
  备份与恢复（本地文件或 WebDAV，也能恢复 Flutter 版的备份）、关于与开源许可。
- 界面有简体中文、English、日本語、Русский。启动中崩溃后下次不自动连接，连续两次会取消选中当前配置。
- 平台各自的：macOS 的菜单栏面板；桌面端的全局快捷键；Windows 的托盘、开机自启、UWP 回环豁免；Android 的分应用代理、按需连接（排除的 Wi-Fi）、
  快捷设置磁贴、外部启停 intent 和 TV 入口。
- po0 与 ggy 自动加白照旧：不论是否连接都持续运行，加白请求始终从真实出口发出。

## 相对 7.2.0

- macOS：采用 macOS 26 原生 Liquid Glass 液态玻璃架构（`NavigationSplitView` 悬浮毛玻璃侧边栏、统一 `NSToolbar` 与 `ToolbarSpacer`、`GlassEffectContainer`、`.buttonStyle(.glassProminent)` / `.buttonStyle(.glass)`、`.glassEffect(.regular, in: ...)`、`Form(.grouped)`，以及带强调色 SF Symbols 徽标的 Bento 响应式仪表盘卡片网格与代理节点卡片网格）。
- Android：重塑为 Material 3 Expressive 卡片网格布局（顶部全宽状态英雄卡片、带 28dp 强调色图标徽章与大字号等宽指标的 `LazyVerticalGrid` 仪表盘卡片、双列圆角代理节点卡片与彩色延迟胶囊、带 34dp 彩色图标徽章的设置分组卡片）。
- Windows：重塑为 Windows 11 WinUI 3（Fluent 2）Bento 四列响应式卡片网格与 SettingsCard 布局（顶部全宽连接横幅、带彩色图标徽章与快速切节点胶囊的 Bento 仪表盘卡片、自适应多列代理节点卡片网格、双列分组工具设置卡片）。

## 已知问题

- 节点组不标记当前是手动选择还是自动选择。
- 连接中不能取消，要等连接完成或失败后再断开。
- macOS：管理员授权弹窗和开机自启只在 CI 中模拟过。
- Windows：安装程序没有签名。
- Android：订阅里把 DNS 写成 `system` 时无法解析；关于页的开源许可只列了内核的依赖，没有列 Android 自己的依赖。
