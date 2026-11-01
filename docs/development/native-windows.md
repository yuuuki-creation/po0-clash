# Windows 原生版

Tauri 2 应用，代码在 `apps/windows`：`src/` 是 Svelte 界面（不用组件库，纯 CSS，跟随系统的深浅色，界面有简中、英、日、俄四种
语言，译文在 `src/lib/locales`），
`src-tauri/` 是 Rust 外壳，直接链接 `crates/core`。整体方案见 [native-rewrite.md](native-rewrite.md)。

## 界面

样式、配色和动画数值按[设计稿](../design/native-ui/README.md)（ADR 0021）：系统字体，不透明的暖灰窗口，不再用液态玻璃和 Mica。
令牌在 `src/styles/tokens.css`，默认强调色的深浅配对也在这里；换了别的强调色时由 `src/lib/accent.js` 算配对值，深色下只提亮到能在
卡片上读清为止。窗口背景色跟着页面色，由外壳在启动时设一次，界面之后保持同步，避免拉伸时露白。

- 外壳：标题栏高 40，有导航按钮、应用图标、名称和窗口按钮。窗口不小于 1008 宽显示 200 宽的完整导航，导航按钮把它收成 48 宽的
  图标栏；更窄时（或关掉「导航显示文字」时）固定是图标栏，导航按钮展开 240 宽的覆盖层。内容区不足 700 时，节点组列表换成下拉框，
  表格依次隐藏类型、规则、Token 和到期列，活动表格不足 900 时还隐藏时间和进程列。仪表盘、配置、加白和工具最宽 1100。
- 仪表盘：顶部是状态行（状态点、状态和运行时长、固定宽度的连接按钮），下面两列放不下就变单列。`dashboardCards` 决定显示哪些行和
  顺序：顺序从左列往下读再接右列，在两列最接近等高的地方断开（`src/lib/dashboard-cards.js`）。内核默认的那份列表按设计稿的布局
  显示，用户改过之后照写的顺序。编辑模式是一列可拖动的行（也可聚焦手柄后按上下键），可移除和添加。当前节点行的节点名打开菜单，
  可切换节点和所看的策略组；延迟点一下单测这个节点。
- 代理：`proxiesLayout` 为标签式时是主从布局，左边是 240 宽、独立滚动的组列表（图标、组名、当前节点），右边是节点表（名称、类型、
  延迟）；列表式是可展开的组，每组一张表。一个搜索框同时匹配组名和节点；排序、定位到当前节点、测试当前组在页面顶部，视图菜单里有
  布局、疏密（行高）、节点列（名称类型延迟 / 名称延迟 / 名称状态点）、策略组图标（`icon`：图片地址、内联 SVG 或 base64；图标和名称 /
  仅图标 / 不显示）和全部测速。点行选节点，点延迟单测这个节点。`selectable` 为假的组只读。
- 配置：表格列出名称、用量和到期，点行切换，拖动排序；每行有更新和更多菜单（编辑、覆写、节点、预览配置、导出、删除）。页面顶部是
  全部更新和添加（订阅链接、分享链接、文件）。每个配置有「覆写」子页：标准（追加规则、MATCH 目标、逐条停用全局规则）、脚本（从
  脚本库选一个，也可在这里新建或编辑）、自定义（策略组 YAML 与规则，可从配置复制）；改完点保存才提交，内核渲染不了或 mihomo
  拒绝时原样显示它的错误。分享链接导入的配置另有「节点」子页，可改名、删除单个节点。
- 加白：总开关和一张表（类型、名称、Token、结果、地址、移除），出错时在该行下面显示原因。
- 活动：请求 / 连接 / 日志三个标签，表格列出时间、主机、进程、规则、链路、流量；可搜索、按级别筛选日志、清空、断开连接。
- 工具：两列分组列表，子页标题是面包屑。外观一行里可直接换主题模式，点这一行进子页。基础配置、网络、DNS、高级（全局追加规则和
  覆写脚本库）、资源（Geo 数据库的信息、更新与下载地址）读写内核的 `EngineOptions`；代理集与规则集、规则列表读内核接口；备份与
  恢复页可备份到文件或 WebDAV、从两者恢复（全部数据或仅配置，按「恢复方式」合并或覆盖），WebDAV 账号可先检查再保存；外观（主题
  模式、纯黑、强调色与自定义色、配色方案、文字大小）、语言和应用开关读写内核的 `AppSettings`。配色方案调整强调色的饱和度。回环页
  列出本机的 UWP 应用容器，逐个或全部设为回环豁免（外壳直接调用 `NetworkIsolation*` 接口，与 `CheckNetIsolation LoopbackExempt`
  改的是同一份名单，需要管理员权限，应用本来就以管理员身份运行）。关于页有开源许可列表，点一项用默认浏览器打开它的地址；在关于页
  连点版本号五次打开开发者模式，工具页才出现「开发者」：消息测试、日志测试、崩溃测试（结束 mihomo 进程）、清除数据（关掉开机自启
  后重启应用，由内核在启动时清空）、清理缓存。快捷键页点一项录制组合键，必须带 Ctrl、Alt 或 Win（F 键除外），退格或 Delete 清除、
  Esc 取消；与其它动作重复的组合会移到当前动作。
- 所有下拉菜单都是自绘的（`src/lib/Popup.svelte`），不用原生 `select`；菜单和对话框挂在 `body` 上，不会被内容区裁剪；提示信息一律用
  对话框。不放说明和副标题，只有错误和实时状态才多一行字；原来写在说明里的格式改成输入框的占位文字。文字不小于 14。
- 动效（`src/lib/motion.svelte.js`、`src/styles`）：切页上滑淡入 250，进子页缩放 250，导航指示条滑动 250，分段控件和标签 167，开关 167，
  选中指示条长出 167，菜单 167 / 83，对话框 250 / 83，删除行 200，添加行 250，换主题 200，速度图每秒匀速滚动一格；搜索过滤和实时数字
  不做动画。「页面切换动画」关掉时只停切页和进子页；Windows 关掉「动画效果」（`prefers-reduced-motion`）时所有动效都停。

## 运行方式

- 程序清单要求管理员权限（`requireAdministrator`），每次手动启动都弹 UAC。只允许一个实例；再次启动会唤出已有窗口。
- 托盘常驻，作为快捷入口；左键单击或菜单里的「打开」显示主窗口。关闭按钮默认只隐藏窗口，应用设置里关掉「关闭时最小化到托盘」
  后会退出应用。「静默启动」时手动打开也不显示窗口，「自动连接」时手动打开后立即连接；界面和托盘的语言跟随应用设置，没设置时
  跟随系统。托盘菜单：连接开关、打开、退出。退出时调用内核的 `launch_finished()` 和 `shutdown()`，清除系统代理。
- 全局快捷键（`src-tauri/src/shell/hotkeys.rs`）：一个专用线程按内核 `AppSettings.hotkeys` 调用 `RegisterHotKey`，同一线程的
  消息循环收 `WM_HOTKEY`；改设置或恢复备份后重新注册，注册失败（被别的程序占用）的动作在快捷键页标红。录制时暂停全部注册，
  让按键进入窗口。动作与 macOS 相同：连接开关、显示 / 隐藏窗口、切换模式（规则 → 全局 → 直连）、切换到系统代理、开关虚拟网卡。
- 启动保护：启动时、自动连接之前调用 `launch_started(None)`。上次启动没走完（内核记录里还是「启动中」）就跳过本次自动连接，
  连续两次还会由内核取消选中当时的配置；窗口第一次打开时用对话框说明。连接结束（或决定不连）后调用 `launch_finished()`。
- 内核数据目录 `%APPDATA%\io.github.yuuukicreation.po0clash\core`。首次启动时，如果存在 Flutter 版的
  `%APPDATA%\io.github.yuuukicreation\po0-clash\shared_preferences.json` 与 `database.sqlite`，交给内核导入。
- `mihomo.exe` 随安装包放在安装目录，由内核启动。sing-tun 自带 wintun，虚拟网卡不需要额外驱动。
- 每 5 秒检查一次到 po0 接口地址的最佳路由（网卡、网关、源地址），变化时调用 `network_changed()`。
  该地址不走虚拟网卡，所以路由反映的总是物理出口。
- 开机自启是计划任务 `po0-clash`：登录时以最高权限运行，带 `--autostart` 参数，启动后不显示窗口；内核的
  `was_connected()` 为真（上次没有手动断开）时自动连接。任务用 XML 创建，去掉 `schtasks /SC ONLOGON` 默认的
  72 小时运行上限、电池限制和低优先级。卸载时删除这个任务。

## 安装与升级

NSIS 安装包，按机器安装到 `C:\Program Files\po0-clash`，与 Flutter 版（Inno Setup）同一个目录。安装钩子
`src-tauri/windows/hooks.nsh` 在复制文件前检查 Flutter 版的卸载键（AppId `67A8CFA2-EC79-4DD3-AB44-75CDD5C3B591`），
存在就静默运行它的卸载程序（会一并卸掉 Helper 服务，不动 `%APPDATA%` 里的数据），再删掉它写在
`HKCU\...\Run` 里的自启项，否则登录时会以普通权限启动这个需要管理员权限的程序并弹出 UAC。原生版第一次启动时，
内核从留下的 `shared_preferences.json` 和 `database.sqlite` 导入订阅和加白条目。Flutter 版的开机自启不迁移，
需要在设置里重新打开。

## 构建

不在本机编译。构建机 `nobrand-tokyo-perf` 的 `/srv/build/po0-native-windows` 里交叉编译（需要 cargo-xwin、clang、
lld、llvm-rc、NSIS、Node、Go）：

```bash
XWIN_CACHE_DIR=/srv/build/po0-native-windows/.xwin-cache apps/windows/scripts/cross-build.sh
```

脚本缺 `mihomo.exe` 时先用 `build-mihomo.sh` 从 `mihomo/upstream` 编译，再执行
`tauri build --runner cargo-xwin --target x86_64-pc-windows-msvc --bundles nsis`，产物在
`target/x86_64-pc-windows-msvc/release/bundle/nsis/`，完整构建约 5 分钟。它在 `target/windows-shims` 里补
Linux 交叉编译的缺口：`clang-cl` 链接、tauri-cli 在 Linux 上查找托盘库用的 pkg-config 占位，以及旧版 NSIS 缺少的
`Win\RestartManager.nsh`。同步源码时不要保留本机的修改时间（`rsync -rlz --checksum`），否则 cargo 可能认为
改过的内核源码比上次的产物旧而不重新编译。

外壳只在 Windows 上编译；在 Linux 和 macOS 上，这个 crate 是空程序，工作区构建不需要 WebKit 或 GTK。

## 测试

在东京的 Windows 11 测试虚拟机（容器 `po0-winvm`）里做，辅助脚本在构建机的 `/srv/build/po0-native-windows/vm`：

- 需要桌面的操作（启动应用、截图）用 `/RU po0 /IT /RL HIGHEST` 的计划任务放到交互会话里；截图也可以直接通过 QEMU
  监视器的 `screendump` 取。
- 应用以管理员身份运行时，WebView2 忽略环境变量和 HKCU 里的启动参数，但认机器策略：在
  `HKLM\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments` 下把值 `po0-clash.exe` 设为
  `--remote-debugging-port=9222`，再用 ssh 把端口转发到构建机。应用里不需要测试专用的代码。
- 从构建机通过 ssh 长时间执行虚拟机里的命令时，连接偶尔会被断开、卡住很久；较长的测试写成脚本，用
  `setsid nohup` 在构建机后台跑，结果写到文件里再读。虚拟机里由 ssh 会话启动的进程会随会话结束，要留着的进程
  （比如测连接列表用的慢速下载）用 `vmgui` 放到交互会话里启动。
- 快捷键的触发用交互会话里的 `SendKeys` 测。它合成的按键没有扫描码，网页收到的 `KeyboardEvent.code` 为空，录制时
  改用 `key` 推出键名。
- 启动保护用伪造的记录测：停掉应用后把内核数据目录里的 `launch.json` 写成 `"starting": true`（再测一次时加上
  `"failures": 1`），再启动应用。
- 系统的保存 / 打开对话框用交互会话里的 `SendKeys` 填路径和回车；中文输入法下路径和回车要分两次发送，否则回车不生效。
- 鼠标操作（拖动窗口、拖边缘缩放）用交互会话里的 PowerShell 调 `SetCursorPos` 和 `mouse_event`；QEMU 监视器的
  `mouse_move` 坐标对不上，会点到别处。
- 切换界面语言（`Set-WinUILanguageOverride`）后要重新登录才生效；`logoff` 之后虚拟机停在锁屏，不会自动登录，
  用 `shutdown /r /t 0` 重启才会自动登录。
- `apps/windows/scripts/smoke.mjs` 通过这个端口调用应用的命令：导入构建机上一个 shadowsocks 节点，分别在系统代理和
  虚拟网卡下连接并请求探测地址（节点的日志里能看到这两个地址），断开后检查系统代理已清除、网卡已删除、没有残留的
  mihomo.exe。用法见脚本开头的环境变量说明。

## CI

`.github/workflows/native-windows.yaml` 只在手动触发时运行，作为发版前的补充检查：在 `windows-latest` 上测试内核、
编译 mihomo 与安装包、静默安装、启动应用并跑不带节点的冒烟测试，最后上传安装包和截图。

## 待定

- 还没有签名。之后沿用 [windows-signing.md](windows-signing.md) 的自签名证书。
- 虚拟网卡在 Windows 上用 `stack: gvisor`（内核 6d780d6 起是默认值）。`mixed` 由系统协议栈处理 TCP，要在虚拟网卡地址上
  监听，Windows 防火墙会弹窗并默认加上阻止规则，结果 TCP 全部超时、只有 DNS 能用。
