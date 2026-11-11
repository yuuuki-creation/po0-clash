# Windows 原生版

Tauri 2 应用，代码在 `apps/windows`：`src/` 是界面，`src-tauri/` 是 Rust 外壳，直接链接 `crates/core`。整体方案见
[native-rewrite.md](native-rewrite.md)。

## 界面

界面是 React、MUI、TypeScript 和 valtio 写的网页，样式照 Clash Verge Rev（ADR 0022）。macOS 版加载同一份网页
（[native-macos.md](native-macos.md)），所以这里的代码不能假定运行在 Tauri 里。

- `src/ipc.ts`：`invoke`、`listen` 和窗口操作。在 Tauri 里走 `@tauri-apps/api`，在 macOS 的 `WKWebView` 里走
  `window.webkit.messageHandlers.po0`，两边的命令名和 JSON 结构相同。`os` 决定画哪种窗口外观和显示哪些平台专有的设置。
- `src/state`：`core.ts` 是全局状态和轮询，`settings.ts` 读写内核的 `AppSettings` 与 `EngineOptions`，`theme.ts` 生成 MUI
  主题，`update.ts` 检查更新。
- `src/layout/Layout.tsx`：36 高的标题栏（Windows 上带窗口按钮），左侧 200 宽的侧边栏放标志、导航和流量区，右键导航可收成
  72 宽的图标栏（`showNavLabels`）。
- `src/base`：页面外框、对话框、开关、卡片、搜索框和代码编辑框。
- `src/pages`：首页（订阅、当前节点、网络接管与连接开关、出站模式、流量、加白、出口 IP、应用信息）、代理（可展开的策略组和
  节点网格）、订阅（卡片网格，覆写和节点管理在对话框里）、连接（活动 / 已关闭，表格或列表）、规则（含代理集与规则集）、日志、
  加白、设置（系统、内核、基础、高级四张卡片，子项在对话框里；回环只在 Windows 显示）。
- 文字在 `src/lib/locales`（简中、英、日、俄）：四个基础文件加 `parts/` 下每个页面一份；`tests/locales.test.mjs` 检查四种语言
  的键一致、用到的键都存在、没有多余的键。
- 配色：默认强调色是 Clash Verge Rev 的蓝色，内核默认值 `0xFF0064E0` 表示「未选择」；选了别的强调色就直接用它。窗口背景色
  跟着主题，由界面通知外壳。
- 更新检查：外壳没有这个命令，界面直接请求 GitHub 的发布列表（`tauri.conf.json` 的 CSP 放行了 `api.github.com`），规则与
  `crates/core/src/update.rs` 相同，实现和测试在 `src/lib/version.js`、`tests/version.test.mjs`。启动时按 `autoCheckUpdate`
  自动检查，有新版时侧边栏标志旁出现 New 按钮；设置里可手动检查。
- 开发：`npm run dev` 后用浏览器打开 `http://localhost:5173`，没有外壳时 `src/mock.ts` 顶替全部命令；加 `?os=macos` 看 macOS
  的外观。发布构建不包含它。`npm run build` 先跑 `tsc`。

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
