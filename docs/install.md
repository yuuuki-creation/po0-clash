# 安装

从 [Releases](https://github.com/yuuuki-creation/po0-clash/releases) 下载对应平台的产物。

po0-clash 是一个**独立的应用**：应用 ID、安装标识、进程名、服务名和数据目录都与官方 FlClash 不同，
可以和官方 FlClash 同时安装、同时运行，互不覆盖。多个代理客户端同时开启系统代理或 TUN 时会互相抢占，
请只在其中一个里打开代理。

## 从旧版 FlClash-po0 迁移

`v0.8.98-po0.1` ～ `po0.6` 这些旧构建仍以「FlClash」的身份安装，po0-clash 不会覆盖或升级它们：

1. 在旧版中打开「备份与恢复」，把备份**导出为本地文件**（WebDAV 备份的目录随应用名变化，po0-clash 读不到旧版的
   WebDAV 备份）。
2. 按下方说明安装 po0-clash，在其「备份与恢复」中导入该文件；po0 token 与订阅、设置一起恢复。
   不想用备份的话，在 po0 页面重新填写 token 即可。
3. 确认 po0-clash 工作正常后，自行卸载旧版：Windows 在「设置 → 应用」中卸载名为 FlClash 的旧版；macOS 删除
   `/Applications/FlClash.app`；Android 卸载旧的 FlClash。旧版不会再收到更新。

## Windows

1. 下载 `po0-clash-<版本>-windows-amd64-setup.exe` 并运行，按向导安装。
2. 不想安装可下载同版本的 `.zip`，解压后运行 `po0-clash.exe`。

安装包有自己的安装标识，不会覆盖已安装的官方 FlClash；po0-clash 的新版本安装包会覆盖升级旧版本 po0-clash，配置保留。

## macOS

在「终端」中执行（自动识别 Apple Silicon / Intel，下载 dmg，安装到 `/Applications/po0-clash.app` 并移除隔离属性）：

```bash
curl -fsSL https://raw.githubusercontent.com/yuuuki-creation/po0-clash/main/scripts/install-macos.sh | bash
```

可选环境变量（写在 `bash` 前，例如 `curl -fsSL ... | PO0CLASH_VERSION=v5.0.0 bash`）：

| 变量 | 说明 |
|---|---|
| `PO0CLASH_VERSION` | 指定 Release 标签，例如 `v5.0.0`；默认最新 Release |
| `PO0CLASH_DMG` | 直接使用本地 dmg 文件或 URL，跳过下载 |
| `PO0CLASH_REPO` | 从其他仓库（`owner/repo`）下载；默认 `yuuuki-creation/po0-clash` |
| `GH_TOKEN` | 可选，GitHub API 限流或私有仓库时使用的 token |

应用未经 Apple 公证，脚本会执行 `xattr -dr com.apple.quarantine /Applications/po0-clash.app`，否则首次打开会被 Gatekeeper 拦截。
脚本不会动 `/Applications/FlClash.app`。

### macOS 原生版（测试版）

7.0.0 起 macOS 改用原生版（菜单栏应用，macOS 13 及以上，Apple Silicon 与 Intel 通用）。安装脚本随每个原生版发布
（`native-v*` 标签）一起上传，在「终端」中执行，例如：

```bash
curl -fsSL https://github.com/yuuuki-creation/po0-clash/releases/download/native-v7.0.0-beta.1/install-macos-native.sh | bash
```

不带参数时安装最新的原生版（包括测试版）；指定版本写在 `bash -s --` 后，例如 `curl -fsSL ... | bash -s -- 7.0.0-beta.1`；
也可以传本地的 `po0-clash-macos.zip` 路径。脚本会核对下载文件的 SHA-256、
应用 ID、架构和签名，退出正在运行的 po0-clash（包括 Flutter 版），替换 `/Applications/po0-clash.app`，移除隔离属性后打开。

原生版与 Flutter 版是同一个应用 ID，会直接替换 Flutter 版；数据目录不动，首次启动时自动导入 Flutter 版的订阅和加白 token，
其它设置不迁移。

## Android

1. 下载与设备架构匹配的 APK（绝大多数手机为 `arm64-v8a`）。
2. 直接安装即可，无需卸载官方 FlClash；两者包名不同，可以共存。同一时间只有一个应用能占用系统 VPN。
3. 在主导航「po0 加白」中添加 token 并打开「自动加白」；**首次开启后重启一次 VPN**，使直连路由生效。

## iOS

不支持。
