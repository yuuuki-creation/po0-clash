# 同步上游

仓库保留了上游完整历史，`upstream` 远程指向 `https://github.com/chen08209/FlClash.git`。

```bash
git remote add upstream https://github.com/chen08209/FlClash.git   # 首次
git fetch upstream --tags
git checkout -b chore/sync-upstream main
git merge upstream/main
```

## 冲突热点

本分支对上游文件的改动刻意保持在少量「接线」位置，合并时重点检查：

| 文件 | 本分支改动 |
|---|---|
| `lib/models/config.dart` | `Config.po0FirewallProps` 字段 |
| `lib/providers/config.dart` | `Po0FirewallSetting` provider、`configProvider`、`buildConfigOverrides` |
| `lib/providers/actions/backup.dart` | 恢复时写回 po0 设置 |
| `lib/providers/actions/setup.dart` | `getProfile` 按总开关传入 `directCidrs`，并注入直连 listener（`withPo0DirectListener`） |
| `lib/models/state.dart` | `MakeRealProfileState.directCidrs` |
| `lib/common/task.dart` | 直连规则与 `route-exclude-address` |
| `lib/providers/state/system.dart` | Android VPN 路由剔除 |
| `lib/manager/app_manager.dart` / `connectivity_manager.dart` | 加白协调器与 po0 / ggy 调度器的启动、网络变化、回到前台、Android 亮屏 / 熄屏 |
| `android/app/src/main/kotlin/com/follow/clash/MainActivity.kt` | 注册 `Po0ScreenPlugin` |
| `lib/enum/enum.dart` / `lib/common/l10n_labels.dart` / `lib/views/navigation.dart` / `lib/pages/shell.dart` | `PageLabel.whitelist` 主导航入口与侧栏状态（ADR 0014 合并 po0 / ggy 入口） |
| `lib/pages/home.dart` | 主页面 fade through 切换（`PageEntrance`），去掉 `_NavigationBarDefaultsM3` |
| `lib/widgets/sheet.dart` / `lib/common/dialog.dart` / `lib/widgets/list.dart` | 去掉模糊选项，模态背景用 Material 3 scrim；侧边面板样式 |
| `lib/widgets/widgets.dart` | 导出 `surface_card.dart` |
| `lib/common/constant.dart` | `repository` 指向本仓库，`upstreamRepository`；应用身份常量（见下节） |
| `lib/common/package.dart` | `compareVersions` 按语义化版本比较（含预发布版本） |
| `lib/common/request.dart` / `lib/views/about.dart` | 检查更新直接比较 `pubspec` 版本；「关于」页链接本仓库与上游 |
| `lib/application.dart` / `lib/common/app_theme.dart` | 主题由 `buildAppTheme` 构建，页面转场用 `appPageTransitionsTheme` |
| `lib/manager/app_manager.dart` / `lib/common/layout.dart` | Material 3 导航侧栏（顶部菜单按钮、可展开）与窗口宽度分级 |
| `lib/common/shape.dart` / `lib/widgets/card.dart` | Material 3 圆角档位；`CommonCard` 的描边 / 填充卡片样式 |
| `lib/common/navigator.dart` | 推入页面改用 `MaterialPageRoute` |
| `lib/widgets/popup.dart` / `chip.dart` / `fade_box.dart` / `super_grid.dart` | 换成 Material 3 组件与动效；删除 `tab*.dart` |
| `lib/widgets/scaffold.dart` 及其 `actions` 调用方（`lib/views/access.dart`、`lib/widgets/input_pages.dart`、`lib/views/config/rules.dart` / `scripts.dart`、`lib/views/profiles/overwrite/overwrite.dart`、`lib/features/overwrite/overwrite_editor_page.dart`） | 工具栏按钮合并进玻璃胶囊并统一高度；调用方不再加 `SizedBox` 间隔与 `CommonMin*ButtonTheme` |
| `lib/common/common.dart` | 导出 `po0_firewall.dart`、`app_theme.dart` |
| `arb/intl_*.arb` | 新增的 `po0*` / `whitelist*`（含导航名 `whitelistNav`）/ `minutesCount` 等文案 |
| `.github/workflows/build.yaml` | 仅手动触发（本分支发版用 `release.yaml`） |
| `README.md` / `README_zh_CN.md` | 整体改写为 po0-clash 说明，合并时保留本分支版本 |
| `assets_source/images/icon/` 及生成的桌面、Android、托盘图标 | po0 的扁平 P / 斜杠零标志，源 SVG 由 `tool/generate_app_icons.sh` 转换为各平台产物 |
| `android/app/src/main/res/drawable/ic_launcher_monochrome.xml` / `android/app/src/main/res/values/splash.xml` | Android 主题图标沿用同一轮廓，启动背景匹配图标底色 |

## 应用身份（ADR 0006）

po0-clash 是独立应用（[ADR 0006](../adr/0006-standalone-app-identity.md)），下列文件里的名称 / ID 都已改成
po0-clash 的值。上游改动这些文件时，**保留本分支的标识**，只合入其余改动；上游新增的任何 `FlClash` /
`flclash` / `com.follow.clash` 字样（进程名、路径、socket、服务名、URL scheme 等）都要逐个判断是否需要改名。
内部命名（Dart 包名 `fl_clash`、Kotlin 包与 Gradle `namespace` `com.follow.clash*`、`FlClash*` 类名、
`clash://` / `clashmeta://`）刻意没有改，合并时保持上游原样。

| 文件 | 本分支改动 |
|---|---|
| `pubspec.yaml` | `version` 为 po0-clash 自己的版本号；**冲突时一律保留本分支的值**，不要带入上游版本号 |
| `android/app/build.gradle.kts` | `applicationId` `io.github.yuuukicreation.po0clash`、读取 `signing.properties` 签名、移除 Firebase 插件与依赖 |
| `android/settings.gradle.kts` / `android/gradle/libs.versions.toml` / `android/common/build.gradle.kts` | 移除 Firebase / google-services |
| `android/.gitignore` | 放行已入库的 `app/keystore.jks` |
| `android/**/AndroidManifest.xml`、`strings.xml`、用到自身包名的 Kotlin 文件 | 应用名与运行时 `packageName`（不再用 namespace 充当应用 ID） |
| `windows/CMakeLists.txt` / `windows/runner/Runner.rc` / `windows/runner/main.cpp` | `BINARY_NAME` `po0-clash`、版本资源的公司 / 产品名、窗口标题 |
| `windows/packaging/exe/make_config.yaml` / `inno_setup.iss` | Inno Setup `AppId`、发布者、可执行文件名、要结束 / 卸载的进程与服务名 |
| `macos/Runner/Configs/*.xcconfig` / `Runner.xcodeproj/project.pbxproj` / `Info.plist` / `xcschemes` | `PRODUCT_NAME`、bundle id（含 debug 与 RunnerTests）、URL scheme |
| `macos/packaging/dmg/make_config.yaml` | dmg 中的 `.app` 名 |
| `linux/CMakeLists.txt` / `linux/runner/my_application.cc` / `linux/packaging/*/make_config.yaml` | `BINARY_NAME`、`APPLICATION_ID`、窗口标题、包名与桌面文件 |
| `services/helper/**` | helper 二进制 / Windows 服务名、systemd 单元、运行目录与 socket、环境变量、协议头 |
| `core/common.go` / `core/tun/tun.go` | 调试环境变量、TUN 设备名 |
| `build_config.yaml` | `core_name` `Po0ClashCore`、`helper_name` `Po0ClashHelperService` |
| `distribute_options.yaml` | `app_name` `po0-clash`（决定产物文件名） |
| `plugins/setup/**` | 内核 / helper 构建产物名 |
| `lib/common/constant.dart` | `appName`、helper 服务名、TUN 设备名、IPC socket / 管道前缀、helper socket 与协议头 |
| `lib/common/path.dart` | 内核可执行文件名、单实例锁文件名 |
| `lib/common/protocol.dart` | URL scheme `po0clash://` 与 Linux URL handler 桌面文件 |
| `lib/bootstrap.dart` / `lib/views/application_setting.dart` | 移除 Crashlytics 提示与开关 |

## 合并后

1. 重新生成代码与文案：`dart run build_runner build --delete-conflicting-outputs`、`dart run intl_utils:generate`。
2. 全局搜索上游新引入的 `FlClash`、`flclash`、`com.follow.clash`、Firebase 相关依赖，按上节规则处理。
3. `bash scripts/vps/verify.sh`。
4. 上游版本号变化不影响 po0-clash 的版本号；需要发版时按 [release.md](release.md) 递增自己的版本。
