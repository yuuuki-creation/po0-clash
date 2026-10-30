# Windows 原生版

Tauri 2 应用，代码在 `apps/windows`：`src/` 是 Svelte 界面（不用组件库，纯 CSS，跟随系统的深浅色与中英文），
`src-tauri/` 是 Rust 外壳，直接链接 `crates/core`。整体方案见 [native-rewrite.md](native-rewrite.md)。

## 界面

样式按 [native-design.md](native-design.md)：仿 macOS 26 访达的无边框窗口。左侧是悬浮的玻璃侧边栏（宽 220、离窗口边 8、
圆角 14，可收起），页面依次为仪表盘、代理、配置、加白、活动、工具；顶部是自绘的统一工具栏（高 52）：页面标题和副标题、成组
放在玻璃胶囊里的图标按钮、实心强调色的启动按钮（连接时「■ 时长」，断开时「▶ 连接」），最右是 Windows 的窗口按钮；内容滚到
工具栏下面时有模糊加渐隐的边缘。窗口背景 Mica（退回 Acrylic），只透过侧边栏一列，内容区是不透明的 `#F2F2F7` / `#1C1C1E`。

- 仪表盘：4 列卡片网格，顺序为当前节点（含同组其它节点的快速切换与单节点测速）、网络速度（最近 60 秒曲线）、出站模式、
  网络接管、加白、流量、连接、内存、内网 IP、订阅、出口 IP。内网 IP 来自内核的 `intranet_ip()`。
- 代理：每个策略组一张卡片，展开后是 4 列节点块（也可切成紧凑或列表），选中的节点是强调色描边加对勾；工具栏有搜索、
  排序（默认 / 延迟 / 名称）、布局、定位到当前节点、全部测速，点节点的延迟单测这个节点。
- 配置、加白：分组列表；配置可导入文件、编辑、预览、导出、拖动排序。
- 活动：请求 / 连接 / 日志三个分段，表格列出时间、主机、进程、规则、链路、流量；可搜索、按级别筛选日志、清空、断开连接。
- 工具：分组列表，子页是最宽 640 的分组表单，工具栏左边有返回按钮。基础配置、网络、DNS、高级（追加规则）、资源（Geo
  数据库的信息、更新与下载地址）读写内核的 `EngineOptions`；代理集与规则集、规则列表读内核接口；外观（主题模式、纯黑、
  强调色与自定义色、配色方案、文字大小）暂存在 WebView 的本地存储里，等内核有应用设置模型后迁过去。其余入口显示「即将推出」。
- 所有下拉菜单都是自绘的玻璃弹出菜单，不用原生 `select`；提示信息一律用对话框。

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
- 从构建机通过 ssh 长时间执行虚拟机里的命令时，连接偶尔会被断开、卡住很久；较长的测试写成脚本，用
  `setsid nohup` 在构建机后台跑，结果写到文件里再读。虚拟机里由 ssh 会话启动的进程会随会话结束，要留着的进程
  （比如测连接列表用的慢速下载）用 `vmgui` 放到交互会话里启动。
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
