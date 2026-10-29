# Windows 原生版

Tauri 2 应用，代码在 `apps/windows`：`src/` 是 Svelte 界面（不用组件库，纯 CSS，跟随系统的深浅色与中英文），
`src-tauri/` 是 Rust 外壳，直接链接 `crates/core`。整体方案见 [native-rewrite.md](native-rewrite.md)。

## 界面

仿照苹果的液态玻璃，保持克制。窗口背景用 Windows 11 的 Mica，不支持时（Windows 10）页面用纯色中性背景。
玻璃材质只用在浮层控件上：底部胶囊标签栏、连接按钮、分段控件和提示条（半透明中性填充、`backdrop-filter`
模糊、1px 细边和柔和阴影）。内容是不透明的分组列表，配色用苹果系统色（强调色系统蓝，状态用绿、橙、红），
图标是单色线条。不用彩色背景、渐变、发光或动画特效，深浅色跟随系统。

## 运行方式

- 程序清单要求管理员权限（`requireAdministrator`），每次手动启动都弹 UAC。只允许一个实例；再次启动会唤出已有窗口。
- 托盘常驻；关闭窗口只是隐藏。托盘菜单：连接开关、打开、退出。退出时调用内核的 `shutdown()`，清除系统代理。
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
