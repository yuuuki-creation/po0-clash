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
- 开机自启是计划任务 `po0-clash`：登录时以最高权限运行，带 `--autostart` 参数，启动后不显示窗口。
  用 XML 创建，去掉 `schtasks /SC ONLOGON` 默认的 72 小时运行上限、电池限制和低优先级。

## 构建

不在本机编译。构建机 `contabo-fr` 上交叉编译（需要 cargo-xwin、clang、lld、llvm-rc、NSIS、Node、Go）：

```bash
apps/windows/scripts/cross-build.sh
```

脚本缺 `mihomo.exe` 时先用 `build-mihomo.sh` 从 `mihomo/upstream` 编译，再执行
`tauri build --runner cargo-xwin --target x86_64-pc-windows-msvc --bundles nsis`，产物在
`target/x86_64-pc-windows-msvc/release/bundle/nsis/`。它在 `target/windows-shims` 里补三处 Linux 交叉编译的缺口：
`clang-cl` 链接、tauri-cli 在 Linux 上查找托盘库用的 pkg-config 占位，以及 Debian 的 NSIS 3.08 缺少的
`Win\RestartManager.nsh`。多人共用构建机时，用 `XWIN_CACHE_DIR` 给 cargo-xwin 指定各自的缓存目录。

安装包是 NSIS，按机器安装到 `C:\Program Files\po0-clash`。外壳只在 Windows 上编译；在 Linux 和 macOS 上，
这个 crate 是空程序，工作区构建不需要 WebKit 或 GTK。

## CI

`.github/workflows/native-windows.yaml` 在 `native*` 分支相关路径的推送和手动触发时运行，环境为 `windows-latest`：
测试内核、编译 mihomo 与安装包、静默安装、启动应用 10 秒并确认进程存活且内核建立了数据目录，最后上传安装包和截图。

## 待定

- 还没有签名。之后沿用 [windows-signing.md](windows-signing.md) 的自签名证书。
- 安装目录、`po0-clash.exe` 和开始菜单快捷方式与 Flutter 版（Inno Setup）相同，两者不要装在同一台机器上。
  替换 Flutter 版时，需要让 NSIS 安装程序先卸载 Inno Setup 版本。
