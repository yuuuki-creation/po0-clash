# 发版

## 版本号

- po0-clash 使用独立的语义化版本，与上游 FlClash 的版本号无关（决策见
  [ADR 0006](../adr/0006-standalone-app-identity.md)）。本仓库的第一个版本是 `5.0.0`，每次发版的版本号由维护者确定。
- 唯一的版本来源是 `pubspec.yaml` 的 `version`，格式 `X.Y.Z+<build>`，例如 `5.0.0+2026092901`：
  - `X.Y.Z`：修复递增 `Z`，新功能递增 `Y`，不兼容的改动（例如配置无法沿用）递增 `X`。
  - `+` 后的构建号即 Android `versionCode`，必须单调递增，沿用 `YYYYMMDDNN` 形式（当天第 `NN` 次构建）。
    同一台设备上的 APK 只能用更大的 `versionCode` 覆盖升级。
- 发版标签为 `v<X.Y.Z>`，即 `pubspec.yaml` 版本去掉 `+<build>`，例如 `v5.0.0`、`v5.0.1`。
  `scripts/check-release-tag.sh` 校验二者一致；`release.yaml` 在构建标签时先运行它，不一致直接失败。
- 旧的 `v0.8.98-po0.N` 标签属于已停用的 FlClash-po0 构建，不再使用，也不要再打 `-po0.N` 形式的标签。
- 应用内「检查更新」指向本仓库（`lib/common/constant.dart` 的 `repository`），按语义化版本比较本机版本与
  最新 Release 的标签，不会把用户引导回官方版。更新弹窗会逐行显示发布说明中以 `- ` 开头的条目，所以
  `docs/release-notes.md` 保持单行、无格式的列表。

## 流程

**只有在维护者明确要求发版时才执行下列步骤。** `release.yaml` 只在推送 `v[0-9]*` 标签或手动运行时触发，
普通推送和 PR 不会构建任何产物。

1. 在 `feat/*` 或 `release/*` 分支上：
   - 改 `pubspec.yaml` 的 `version`（版本号与构建号都要递增）；
   - 把 `docs/release-notes.md` 改写成本次版本的发布说明；
   - VPS 上 `bash scripts/vps/verify.sh` 通过。
2. 通过 PR 合入 `main`（需人工审阅）。
3. 在 `main` 的该提交上打标签并推送：
   ```bash
   bash scripts/check-release-tag.sh v5.0.1
   git tag v5.0.1
   git push origin v5.0.1
   ```
4. 标签推送触发 `.github/workflows/release.yaml`：
   - 并行构建 Android（`ubuntu-latest`，三个 ABI 的 APK）、Windows x64（`exe` 安装包与 `zip`）、
     macOS arm64 与 x64（`dmg`），全部使用 `dart setup.dart <platform> --env stable`；
   - 全部成功后创建标题为 `po0-clash v5.0.1` 的 Release（说明取自 `docs/release-notes.md`），上传所有产物与
     `scripts/install-macos.sh`。
   Release 已存在时只追加 / 覆盖产物，不改说明。任一平台失败时不会发布，修复后删除标签重新推送，或在 Actions
   页面手动运行并填写 `tag`。

手动运行（`workflow_dispatch`）时 `tag` 留空只构建、把产物留在本次运行上，便于试装；填写标签则发布到该 Release。

## 产物

| 平台 | 文件 | 安装方式 |
|---|---|---|
| Windows x64 | `po0-clash-<ver>-windows-amd64-setup.exe` / `.zip` | 运行安装包，或解压 zip |
| macOS arm64 / x64 | `po0-clash-<ver>-macos-{arm64,amd64}.dmg` | 终端命令，见 [install.md](../install.md) |
| Android | `po0-clash-<ver>-android-{arm64-v8a,armeabi-v7a,x86_64}.apk` | 直接安装 APK |

`<ver>` 为不含 `v` 的版本号，例如 `po0-clash-5.0.1-android-arm64-v8a.apk`。

发布说明需包含：本次新增与修复、升级注意事项、已知限制（例如 ggy 加白链接每次请求都会写入）。
