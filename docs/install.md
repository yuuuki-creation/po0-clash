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

## Windows（10 / 11，x64）

在 PowerShell 中粘贴整行命令。脚本会完整下载后再执行，校验安装包 SHA-256，并请求管理员权限安装。

```powershell
$p = Join-Path $env:TEMP "po0-clash-$(New-Guid).ps1"; try { Invoke-WebRequest -UseBasicParsing -ErrorAction Stop -Uri https://github.com/yuuuki-creation/po0-clash/releases/download/native-v8.4.1/install.ps1 -OutFile $p; powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p -Version 8.4.1; if ($LASTEXITCODE) { throw "Installer exited with code $LASTEXITCODE." } } catch { throw } finally { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
```

也可直接下载并双击 `po0-clash-<版本>-windows-x64-setup.exe`。要安装其他版本，下载 `install.ps1` 后，用 PowerShell 的 `-File` 执行脚本并通过 `-Version` 指定版本。

## macOS（13 及以上，Apple 芯片与 Intel）

在「终端」中粘贴整行命令。脚本会完整下载后再执行，核对安装包的 SHA-256、应用 ID、架构和签名，然后安装到「应用程序」并启动。

```bash
(p=$(/usr/bin/mktemp) && trap '/bin/rm -f "$p"' EXIT && /usr/bin/curl -q -fsSL --retry 3 -o "$p" https://github.com/yuuuki-creation/po0-clash/releases/download/native-v8.4.1/install.sh && /bin/bash "$p" 8.4.1)
```

上述命令安装8.4.1 稳定原生版。要指定版本或使用本地 ZIP，先下载 `install.sh`，再用 Bash 执行脚本并传入版本号或 ZIP 路径。

```bash
/bin/bash "$HOME/Downloads/install.sh" 8.4.1
```

```bash
/bin/bash "$HOME/Downloads/install.sh" "$HOME/Downloads/po0-clash-macos.zip"
```

原生版会覆盖升级同一应用 ID 的 Flutter 版，首次启动会导入旧版订阅和加白条目。首次开启虚拟网卡时，macOS 会请求管理员授权。

## Android

1. 下载与设备架构匹配的 APK（绝大多数手机为 `arm64-v8a`）。
2. 直接安装即可，无需卸载官方 FlClash；两者包名不同，可以共存。同一时间只有一个应用能占用系统 VPN。
3. 在主导航「po0 加白」中添加 token 并打开「自动加白」；**首次开启后重启一次 VPN**，使直连路由生效。

## iOS

不支持。
