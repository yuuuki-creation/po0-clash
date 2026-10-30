# Windows 原生版

Tauri 2 应用，代码在 `apps/windows`：`src/` 是 Svelte 界面（不用组件库，纯 CSS，跟随系统的深浅色与中英文），
`src-tauri/` 是 Rust 外壳，直接链接 `crates/core`。整体方案见 [native-rewrite.md](native-rewrite.md)。

## 界面

主窗口仿 macOS 26「访达」（ADR 0019、ADR 0020）：无边框窗口，自绘的统一工具栏和标题栏合为一行，左侧是悬浮的玻璃侧边栏
（四周内缩 8px、圆角 16px，可在工具栏里收起），页面依次为仪表盘、代理、配置、加白、活动、工具。工具栏左侧是侧边栏开关和
页面标题（带一行副标题：连接状态、当前节点或加白数），右侧是成组放进玻璃胶囊的纯图标按钮，最右是 Windows 的最小化、
最大化、关闭按钮；空白处可拖动窗口，双击最大化。内容滚到工具栏下面时有一段模糊加渐隐的滚动边缘。

- 仪表盘：FlClash 的卡片网格（速率、出口 IP、当前节点、模式、接管方式、配置、自动加白），右下角浮动的启动按钮未连接时是
  蓝色着色玻璃「连接」，连上后是普通玻璃显示已连接时长；连接失败时顶部有错误卡片和「重新连接」。
- 代理：每个策略组一行组标题，下面直接是节点卡片网格，选中的节点是强调色底加蓝描边。
- 配置、加白、工具：macOS 式的分组表单。工具页的入口与 Flutter 版一致；还没有内核接口的入口打开「即将推出」的空状态页，
  开机自启在「应用」里，诊断日志在「其他」里（工具栏也有导出按钮），版本在「关于」里。活动页的请求 / 连接 / 日志同样是
  「即将推出」。
- 提示信息一律用对话框，不在页面里放横幅。

样式按液态玻璃，保持克制：窗口背景 Windows 11 的 Mica，退回 Acrylic（按系统深浅色加近不透明的底色），上面铺中性的内容底色
（浅色近白、深色 #1E1E1E）；`backdrop-filter` 玻璃只用在浮动的功能层（侧边栏、工具栏按钮组、启动按钮、对话框）。内容是很淡的
灰色填充分组，强调色系统蓝，状态用绿、橙、红，图标单色。不用渐变、彩色背景或发光，深浅色跟随系统。Win11 的窗口圆角由
DWM 画，测试虚拟机没有显卡加速，所以截图里是直角。

## 运行方式

- 程序清单要求管理员权限（`requireAdministrator`），每次手动启动都弹 UAC。只允许一个实例；再次启动会唤出已有窗口。
- 托盘常驻，作为快捷入口；左键单击或菜单里的「打开」显示主窗口，主窗口的关闭按钮只是隐藏。托盘菜单：连接开关、打开、退出。退出时调用内核的 `shutdown()`，清除系统代理。
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
- 虚拟网卡需要内核在 Windows 上改用 `stack: gvisor`。现在的 `mixed` 由系统协议栈处理 TCP，要在虚拟网卡地址上监听，
  Windows 防火墙会弹窗并默认加上阻止规则（阻止优先于 sing-tun 自己加的允许规则），结果 TCP 全部超时、只有 DNS 能用。
  测试虚拟机里换成 gvisor 后两种模式都正常，也不再弹防火墙提示。
