# 构建

Go 内核与 Rust Helper 通过 Dart build hook 构建，`setup.dart` 负责打包。Windows 使用本分支的
PowerShell / Inno Setup 签名流程，其余平台使用 distributor，细节见 [.agents/commands.md](../../.agents/commands.md)
与 [Windows 自签名](windows-signing.md)。

| 目标 | 构建位置 | 原因 |
|---|---|---|
| Android APK | GitHub Actions `ubuntu-latest` | 与桌面端同一个发版工作流，签名文件已入库，无需额外密钥 |
| Windows 安装包 / zip | GitHub Actions `windows-2022` | Flutter 不支持在 Linux 上交叉编译 Windows 桌面端 |
| macOS dmg | GitHub Actions `macos-latest`（arm64）与 `macos-15-intel`（x64） | 同上，需要 Xcode |
| format / analyze / test / 代码生成 | 构建 VPS | Windows 本机 `flutter pub get` 需要开发者模式（符号链接） |

工具链版本与上游 CI 保持一致：Flutter 3.47.1、Go 1.26.4、NDK r28c（28.2.13676358）、JDK 17、Rust 1.95.0（由
`plugins/rust_api/rust/rust-toolchain.toml` 固定）。

## 构建 VPS（只做校验）

当前使用机器管理仓库中的 `hostdzire-nl`，已有工具链位于 `/opt/toolchains/flutter`、`/opt/toolchains/go` 和 `/opt/toolchains/rust-1.95.0`，
工作区位于 `/srv/build/po0-clash`。并行任务使用独立的 `/srv/build/po0-<任务名>` 目录。连接参数和机器使用约定以
私有机器管理仓库为准；不要继续使用缺少当前端口的旧 `flclash-vps` 别名。

`scripts/vps/verify.sh` 优先使用这套现有 Flutter / Go 工具链，同时兼容下列旧版初始化脚本的目录。
原生 Rust 校验先将 `/opt/toolchains/rust-1.95.0/bin` 加入 `PATH`。Go 文件权限测试以非 root 用户执行，
避免 root 绕过目录权限导致断言失真；为测试用户指定独立的 `GOCACHE`、`GOMODCACHE` 和 `GOTMPDIR`。

桌面 Core 默认只将错误与致命诊断写入 stderr，由直接启动器或 Helper 收集；普通日志继续通过 Core 事件通道进入应用。
排查原生问题时，可为 Core 进程设置 `PO0CLASH_CORE_DEBUG=1`，将完整控制台日志写入 stderr。Android 保留现有控制台输出。

事件编码基准在 `core/` 内运行 `CGO_ENABLED=0 go test -run '^$' -bench '^BenchmarkMessageBatchEncoding$' -benchmem .`，
覆盖每批 32 条日志、请求、含 Unicode / IPv6 zone 的请求和测速事件。`marshal` 为标准编码基准，`reused` 为实际批发送路径；
结果描述合成事件的编码成本，不等同于整机 CPU / RSS。常规 Go 测试同时执行完整字段、空值、转义、时间和随机差分校验。

一次性初始化（root）：

```bash
bash scripts/vps/provision.sh
```

脚本把工具链装到 `/opt/flclash-toolchain`，并写入 `/etc/profile.d/flclash-toolchain.sh`。
仓库是公开的，VPS 直接用 HTTPS（`https://github.com/yuuuki-creation/po0-clash.git`）克隆到 `/root/FlClash-po0`，不需要 deploy key；
子模块 `core/Clash.Meta` 通过 `url.https://github.com/.insteadOf git@github.com:` 走 HTTPS。

```bash
bash scripts/vps/verify.sh            # format 检查 + analyze + test + 覆盖率门槛
```

`verify.sh` 会临时把 `pubspec.yaml` 中的 `build_assets` 置为 `false`（跳过 Go / Rust 原生构建）并在退出时恢复。
**永远不要提交 `build_assets: false`**，`setup.dart` 会拒绝在该状态下打包。

构建机只有 11 GB 内存，`provision.sh` 会创建 8 GB swap。VPS 不再构建发版 APK；需要本地试打包时可以在 VPS 上运行
`dart setup.dart android --env stable`，但产物只用于测试，正式产物一律来自 GitHub Actions。

## Android VPN 接管回归

在 NL 的 Android 模拟器上验证，独立测试 APK 使用另一个 UID 模拟先于 VPN 启动的应用。
同一测试还覆盖 VPN 内存回收时 Core 的已有 TCP/UDP 连接、接管后的新连接，以及迁移后主动开启绕过的行为。
`validation` 是通过 `-Ppo0-validation` 临时启用的测试构建类型，使用 release Flutter 引擎并保留可供 instrumentation 调用的原生类；不会发布到 GitHub。
使用可丢弃的独立模拟器；若已有正式分包，先准备干净的测试设备数据。临时构建号没有正式分包的 ABI 偏移，不能假定可以直接覆盖。

```bash
python3 tool/android_vpn_fixture.py            # 另一个终端；只监听 NL 本机 127.0.0.1:18780
./android/gradlew -p android :app:assembleValidation :app:assembleValidationAndroidTest \
  -Ppo0-validation -Ptarget-platform=android-x64
adb install -r build/app/outputs/apk/validation/app-validation.apk
adb install -r build/app/outputs/apk/androidTest/validation/app-validation-androidTest.apk
adb shell appops set io.github.yuuukicreation.po0clash ACTIVATE_VPN allow
adb shell am instrument -w \
  io.github.yuuukicreation.po0clash.test/com.follow.clash.VpnTakeoverInstrumentation | tee takeover.log
grep -q '^VPN takeover:.*passed' takeover.log
```

`am instrument` 本身的退出码不能证明成功，必须检查最终结果。保留旧的 `allowBypass` 行为时，
用例应报 `Stale connection retained with bypass policy 0`；修复后应通过。
Android 只在禁止绕过的 VPN 上清理接管前的 TCP 连接，见
[AOSP ConnectivityService 的 maybeCloseSockets / updateVpnUidRanges](https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/service/src/com/android/server/ConnectivityService.java)。

## 常驻内存验证

采样口径、基线、回收边界与尚未完成的平台验证见 [常驻内存验证](resident-memory.md)。
必须同时记录 PSS / RSS 与交换内存；桌面需要累加 UI 和 Core，不能只报告内核堆。

## Windows 原生验证

`windows-validation.yaml` 为本仓库相关 PR 和手动请求执行 Windows 上的 build hooks、Rust IPC / Helper 与签名安装流程验证。
签名安装测试使用临时测试程序，不构建或发布正式应用；详见 [Windows 自签名](windows-signing.md#原生验证)。

## GitHub Actions（发版构建）

`.github/workflows/release.yaml`：

- 触发：只在推送 `v[0-9]*` 标签，或在 Actions 页面手动运行（`workflow_dispatch`，可选填要发布到的标签）时运行。
  **不在分支推送或 PR 上运行**；在维护者明确要求发版之前，不要推送版本标签或手动触发它。
- 任务：Android（三个 ABI 的 APK）、Windows x64（`exe,zip`）、macOS arm64 与 x64（`dmg`），全部使用
  `dart setup.dart <platform> --env stable`；标签构建会先运行 `scripts/check-release-tag.sh`。
- Android 任务按上游 `build.yaml` 的 Android 部分配置（JDK 17、NDK r28c、Gradle、Go、Flutter、Rust 缓存），
  但没有解码密钥 / `google-services.json` 的步骤：签名文件已入库，应用也不再集成 Firebase。
- 全部平台成功后，产物与 `scripts/install-macos.sh` 上传到同名 GitHub Release（流程见 [release.md](release.md)）。

上游的 `.github/workflows/build.yaml` 保持仅手动触发，不用于本分支发版。

## Android 签名

- 发版签名文件**有意提交在仓库中**：`android/app/keystore.jks` 与 `android/signing.properties`
  （`storePassword` / `keyAlias` / `keyPassword`），由 `android/app/build.gradle.kts` 直接读取，CI 不需要任何 secret。
  这是仓库所有者接受其公开的决定，见 [ADR 0006](../adr/0006-standalone-app-identity.md)。
- 两个文件缺一不可，否则 release 构建退回 debug 签名并加上 `.dev` 应用 ID 后缀，产物成了另一个应用，
  不能覆盖升级已安装的 po0-clash。
- 不要替换或重新生成 keystore：签名一变，所有用户都必须卸载重装。除这两个文件外，其他密钥、token、
  `android/local.properties` 仍然不得入库。
- 应用 ID 为 `io.github.yuuukicreation.po0clash`，与官方 FlClash（`com.follow.clash`）不同，两者可以同时安装。

## 本地开发（Windows）

本机可直接编辑代码；需要运行 Flutter 工具时，把改动同步到 VPS 执行：

```bash
git push origin HEAD                          # 或用 tar 同步未提交的改动
ssh hostdzire-nl 'cd /srv/build/po0-clash && git fetch && git checkout <branch> && bash scripts/vps/verify.sh'
```

若本机开启了 Windows 开发者模式，也可以直接在本机运行 `flutter pub get` / `flutter test`（同样先关闭 `build_assets`）。
