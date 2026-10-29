# 同步上游

仓库保留了上游完整历史，`upstream` 远程指向 `https://github.com/chen08209/FlClash.git`。

```bash
git remote add upstream https://github.com/chen08209/FlClash.git   # 首次
git fetch upstream --tags
git checkout -b chore/sync-upstream main
git merge upstream/main
```

## 前端基准

2026-10-24 的前端同步以最新稳定版 **v0.9.1**（`8d4f9744948751f1273fe871e1d05276fac09b0e`）为基准，
不合并上游内核、平台生命周期或应用身份。上游的 `lib/ui/` 在本分支保留现有目录接口：

| 上游实现 | 本分支位置 / 适配 |
|---|---|
| `ui/shape.dart`、`ui/typography.dart` | `lib/common/shape.dart`、`typography.dart`；兼容旧圆角名称 |
| `ui/icons/` | `lib/widgets/glyphs/`；`AppIcon` 将已有 Material 图标参数映射到上游 glyph |
| `ui/selection_mark.dart` | `lib/widgets/selection_badge.dart`；代理实际选中与固定偏好分别展示 |
| `views/proxies/group_tabs.dart` | 同路径；复用现有弹出菜单，`lib/widgets/text.dart` 同步 emoji 字体测量 |
| `ui/surface.dart`、主题与首页卡片 | `lib/common/upstream_color.dart`、`lib/widgets/upstream_surface.dart`、`lib/views/dashboard/` |
| 连接 / 请求表格 | `lib/features/connection/tracker_info_table.dart`，接现有 `TrackerInfo`，保留窄屏列表；排序结果按列表快照复用，文本排序键每行只生成一次 |
| 上游没有的页面 | `lib/views/po0_firewall.dart`、`lib/views/profiles/nodes.dart`，复用同一视觉组件 |

新增前端接线还涉及 `lib/widgets/button.dart`（图标参数接受 Widget）、`lib/widgets/scaffold.dart`、
`lib/features/connection/connection.dart`、`lib/views/connection/{connections,requests}.dart`、
`lib/views/proxies/{card,tab,proxies}.dart`、`lib/views/profiles/{add,profiles}.dart`、`lib/views/theme.dart` 和 `lib/views/tools.dart`。
`pubspec.yaml` 将 glyph 路径解析所需的 `path_parsing` 声明为直接依赖；它之前已在锁文件中作为传递依赖存在。
首页还同步了上游的 `layout.dart`、`style.dart`、`widgets/{card,current_outbound,traffic,outbound_mode,network_takeover,intranet_ip}.dart`，
`lib/widgets/{traffic_chart,elastic_press}.dart` 与上游颜色生成器；数据适配集中在 `lib/views/dashboard/widgets/summaries.dart`。
`lib/models/ip_quality.dart`、`lib/providers/ip_quality.dart`、`lib/common/ip_quality.dart` 与对应测试沿用上游查询实现。

Android 快捷启动接线涉及 `android/app/.../{QuickActionActivity,MainActivity,ServiceState,ServiceStateHost,Ext}.kt`、
`plugins/AppPlugin.kt`、`models/State.kt`，以及 `lib/{bootstrap,plugins/app}.dart`、`lib/models/state.dart`、
`lib/providers/state/system.dart`、`lib/providers/actions/setup.dart`。保留 `ServiceState` 的原生意图仲裁；引擎就绪门控只决定命令接收方。
旧版共享状态缺少加白标志时，仅从保存的总开关迁移，不复制或记录 token。
Android 图标升级兼容由 `LauncherBranding.kt`、`LauncherUpdateReceiver.kt`、`FlClashApplication.kt` 与
`res/values/launcher.xml` 接线：独立资源入口、`roundIcon`、包替换及首次启动刷新、已固定快捷方式更新；
`TileService.kt` 显式同步当前单色图标。保持 `MainActivity` 组件名不变，刷新时只在默认 / 显式启用状态之间切换，不禁用启动器。


界面与保留的性能约定见 [前端界面](../features/glass-ui.md)。

## 冲突热点

本分支对上游文件的改动刻意保持在少量「接线」位置，合并时重点检查：

| 文件 | 本分支改动 |
|---|---|
| `lib/models/config.dart` | `Config.po0FirewallProps`、`Config.nodeProfileId` 字段 |
| `lib/providers/config.dart` | `Po0FirewallSetting`、`NodeProfileId` provider、`configProvider`、`buildConfigOverrides` |
| `lib/providers/actions/backup.dart` | 恢复时写回 po0 设置与 `nodeProfileId` |
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
| `lib/common/request.dart` / `lib/views/about.dart` | 检查更新直接比较 `pubspec` 版本；「关于」页介绍 po0-clash，上游来源集中在「开源致谢」 |
| `lib/common/app_localizations.dart` / `lib/core/desktop/launch_policy.dart` | 按原始 Windows 错误码区分杀毒检测、签名验证和策略拦截；智能应用控制评估状态不参与归因 |
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

## Android 启动接管

| 文件 | 本分支改动 |
|---|---|
| `lib/providers/actions/setup.dart` | Android 先准备配置再提交启动，取消启动后的延迟强制重载；相同配置复用已有内核状态，失败使配置指纹失效；准备期间 Wi-Fi 暂停状态不能提前启动 |
| `lib/core/lib.dart` / `android/app/src/main/kotlin/com/follow/clash/plugins/ServicePlugin.kt` | 启动前同步最新 VPN 参数；原生共享状态按通道顺序应用，启动命令仍由 `ServiceState` 乐观接收并仲裁 |
| `core/lib.go` | TUN 协议栈返回前已可能收包，保护套接字与 UID 查询以 JNI 回调有效性判断就绪，不等待 listener 字段赋值 |
| `lib/models/{config,core}.dart` / `android/service/.../models/VpnOptions.kt` / `VpnService.kt` | 默认关闭 VPN 绕过；配置与原生共享状态按 `bypassPolicyVersion` 迁移旧默认值，让 Android 清理接管前的 TCP 连接；迁移后主动开启绕过仍有效 |
| `lib/models/config.dart` | 默认主题跟随系统；缺少 `themeModePolicyVersion` 的旧主题升级后重置一次，之后保留手动选择 |
| `lib/views/dashboard/widgets/summaries.dart` | 网站延迟经 mixed 入口发起真实 HEAD 请求，遵循当前分流规则；路由变化取消旧请求并清理结果，不复用节点测速缓存 |

## 简洁界面与性能（ADR 0016）

| 本轮常驻内存集成文件 | 分支行为 |
|---|---|
| `lib/bootstrap.dart` / `lib/manager/app_manager.dart` | 初始化缓存预算，按 UI 可见性延迟释放可重建缓存和闲置分配器页，恢复前台取消过期回收 |
| `android/app/src/main/kotlin/com/follow/clash/{MainActivity,ServiceController}.kt` | 后台内存压力通知与已加载 Core 的回收，不新增服务生命周期所有者 |
| `android/core/src/main/cpp/{core.cpp,CMakeLists.txt}` / `core/hub.go` | GC 归还闲置 Go 页，Android 分配器释放空闲空间，回收干净文件映射 |
| `plugins/setup/setup_hooks/lib/src/go_builder.dart` | Android 使用 upstream `with_low_memory` 构建标签；构建与依赖指纹使用同一标签 |

| 文件 | 本分支改动 |
|---|---|
| `lib/common/glass.dart` / `app_theme.dart` / `shape.dart` / `dialog.dart` | 中性色表面、蓝色主操作和圆角矩形；去掉模糊与玻璃装饰 |
| `lib/widgets/glass.dart` / `glass_segmented.dart` | 不透明 Material 表面与标准分段按钮；沿用现有接口 |
| `lib/pages/home.dart` / `shell.dart` / `lib/views/navigation.dart` | 标准底栏和侧栏，桌面也有首页，内容不被底栏覆盖 |
| `lib/views/control/` | 首页的连接、配置、统计分组；流量图重绘隔离 |
| `lib/providers/app.dart` / `actions/setup.dart` / `actions/system.dart` | UI 可见性与主页统计采样；托盘网速例外，保留 Core 计数与运行意图 |
| `lib/manager/app_manager.dart` / `window_manager.dart` | 生命周期、最小化与恢复驱动 UI 可见性；重新聚焦不额外加白 |
| `lib/widgets/active_polling.dart` / `line_chart.dart` / `lib/views/po0_firewall.dart` | 不可见时停轮询；相同图表数据不重启动画 |
| `lib/providers/state/system.dart` / `proxies.dart` | 隐藏托盘网速时不订阅流量；节点规范化复用未变对象 |
| `lib/models/common.dart` / `lib/common/task.dart` | 失效的节点偏好回退到当前出口；首次默认节点在排序前确定，分组复用节点对象；解析复用只读 Map，分组只复制一次 |
| `lib/common/compute.dart` / `lib/providers/state/proxies.dart` / `lib/providers/actions/proxies.dart` | 节点名索引、快照内出口解析缓存、循环保护和延迟排序键复用；叶节点不分配循环检测集合 |
| `core/proxies.go` / `core/constant.go` / `core/hub.go` | 分离节点列表处理，仅输出 Flutter 消费的字段；分组成员保留 JSON 数组，叶节点直接编码，保留运行时出口与原有消息封装 |
| `lib/common/fixed.dart` / `lib/models/common.dart` | 有上限的环形缓冲、不可变快照与列表筛选快速路径；历史拼接和队列复制省去中间列表 |
| `lib/widgets/active_feed.dart` / `lib/widgets/widgets.dart` / `lib/views/logs.dart` / `lib/views/connection/requests.dart` | 由数据事件触发、按页面 / 窗口 / 生命周期可见性合并的列表刷新，隐藏期间继续记录事件 |
| `lib/providers/state/system.dart` / `lib/providers/actions/system.dart` | 托盘直接读取最新流量采样，避免为标题构建完整快照 |
| `core/server.go` | 有上限的每连接接收缓冲区复用，异步分发前复制 JSON 参数 |
| `core/message.go` / `core/message_encoding.go` / `core/event_json.go` / `core/request_events.go` / `core/hub.go` | 有上限的编码缓冲；固定事件专用 JSON 写入及标准编码回退，完整字段契约与随机差分校验；请求排队仅保留展示信息，Android 避免重复 GC |
| `core/main.go` / `core/logging.go` / `core/go.mod` | 桌面入口按调试开关控制控制台诊断，普通日志沿用事件通道；显式声明已有 logrus 依赖 |
| `lib/core/event.dart` / `lib/core/desktop/rpc_client.dart` / `lib/plugins/service.dart` | UTF-8 / JSON 融合解码、匹配 Map 直接复用、监听器快照缓存及不可变事件模型共享；保留回调顺序和异常隔离 |
| `lib/core/interface.dart` | 连接列表和供应器列表解码复用类型已匹配的 Map，避免逐条复制 |
| `lib/common/compute.dart` / `lib/providers/state/proxies.dart` / `lib/providers/actions/proxies.dart` | 明确指定的测速网址优先于分组与全局默认值；任务、结果与进行中状态共用地址解析，服务检测按各自目标分别测速 |
| `lib/manager/core_manager.dart` | 测速结果与请求事件使用同步回调，省去无异步工作的 Future 分配 |
| `android/service/src/main/java/com/follow/clash/service/modules/NotificationModule.kt` / `SuspendModule.kt` | 模块持有可取消子任务，停止与最终副作用串行，防止停止后的回调恢复通知或休眠状态；通知熄屏时取消刷新循环 |
| `android/service/src/main/java/com/follow/clash/service/modules/NetworkObserveModule.kt` | 停止清理与网络回调共用锁，禁止停止后重新投递 DNS 延迟任务；缓存网络能力通知，避免排序时重复 Binder 查询 |
| `android/service/src/main/java/com/follow/clash/service/VpnService.kt` | UID 到包名缓存采用 512 项 LRU，停止 TUN 后清空；先停 TUN/listener 再恢复休眠状态，避免退出时触发健康检查 |
| `android/app/src/main/kotlin/com/follow/clash/packages/PackageResolver.kt` | APK 识别扫描串行、可取消，结果随已安装应用缓存一起失效；包变更期间的旧扫描结果不会重新写入缓存 |
| `android/app/src/main/kotlin/com/follow/clash/plugins/AppPlugin.kt` | 引擎销毁时清理 Activity 绑定；延后执行的权限请求拒绝已销毁引擎，扫描任务传播取消，避免完成后向旧引擎回传 |
| `android/app/src/main/kotlin/com/follow/clash/plugins/ServicePlugin.kt` / `CoreEventRelay.kt` | 四批待发事件与单批在途回执，单一发送协程向 Dart 投递；先取消队列再移除 JNI 回调，避免无界主线程任务与销毁等待 |
| `android/app/src/main/kotlin/com/follow/clash/ServiceController.kt` | 统一拥有 JNI 事件监听器；按 relay 身份释放，旧引擎销毁不覆盖新引擎监听器 |
| `core/lib.go` / `core/server.go` / `core/message.go` / `core/hub.go` | Android 无事件监听器时跳过事件排队与请求快照；消费者状态由 JNI 监听器安装/释放同步，桌面队列行为保持原有语义 |
| `android/common/src/main/java/com/follow/clash/common/BroadcastLease.kt` | 原子消费并清空结束回调，watchdog 提前释放后不再持有 PendingResult；服务操作继续由原有 owner 完成 |
| `android/app/src/main/kotlin/com/follow/clash/TileService.kt` | 服务销毁时兜底取消状态收集任务 |
| `plugins/rust_api/rust/src/ipc/{server,queue,frame,platform,readiness}.rs` | 消息/关闭驱动发送，接收时预留事件字节；Unix 通过描述符就绪与显式唤醒等待，Windows 保留原有管道处理 |

## Rust 应用后端（ADR 0017）

| 上游文件 | 本分支改动 |
|---|---|
| `plugins/rust_api/rust/{Cargo.toml,Cargo.lock,src/lib.rs,src/api/mod.rs}`、`plugins/rust_api/lib/rust_api.dart` | 新增 `whitelist` 模块与 `ureq`（rustls）依赖；合并上游 rust_api 时保留该模块，再用 `flutter_rust_bridge_codegen generate` 重新生成绑定 |
| `scripts/vps/verify.sh`（本分支自有） | 在 Flutter 检查前运行 rust_api 的 `cargo fmt` / `clippy` / `test` |

## Windows 签名验证

`.github/workflows/windows-validation.yaml` 与 `scripts/windows/test-signing.ps1` 在 Windows runner 上验证签名、打包、安装和卸载，测试程序替代 Flutter 产物生成，不触发正式发版。

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
| `windows/packaging/exe/inno_setup.iss` | 原生 Inno Setup 脚本；保留独立应用身份与升级清理，签名安装和卸载程序；旧 distributor 配置已移除 |
| `macos/Runner/Configs/*.xcconfig` / `Runner.xcodeproj/project.pbxproj` / `Info.plist` / `xcschemes` | `PRODUCT_NAME`、bundle id（含 debug 与 RunnerTests）、URL scheme |
| `macos/packaging/dmg/make_config.yaml` | dmg 中的 `.app` 名 |
| `linux/CMakeLists.txt` / `linux/runner/my_application.cc` / `linux/packaging/*/make_config.yaml` | `BINARY_NAME`、`APPLICATION_ID`、窗口标题、包名与桌面文件 |
| `services/helper/**` | helper 二进制 / Windows 服务名、systemd 单元、运行目录与 socket、环境变量、协议头 |
| `core/common.go` / `core/tun/tun.go` | 调试环境变量、TUN 设备名 |
| `core/constant.go` / `lib/core/method.dart` / `lib/core/interface.dart` / `lib/core/controller.dart` | 内核方法 `convertShareLinks`（ADR 0015） |
| `lib/providers/actions/profiles.dart` / `lib/providers/action.dart` / `lib/providers/providers.dart` | `addProfileFormURL` 把分享链接转给节点导入；导出 `node_profile.dart` |
| `lib/views/profiles/add.dart` / `lib/views/profiles/profiles.dart` | 「分享链接」添加入口；「手动节点」配置菜单里的「节点」页 |
| `lib/pages/scan.dart` / `lib/common/picker.dart` | 扫码与二维码图片放行分享链接 |
| `pubspec.yaml` | `yaml` 从 dev 依赖改为正式依赖（读取节点配置模板） |
| `build_config.yaml` | `core_name` `Po0ClashCore`、`helper_name` `Po0ClashHelperService` |
| `distribute_options.yaml` | `app_name` `po0-clash`（决定产物文件名） |
| `plugins/setup/**` | 内核 / helper 构建产物名；Windows Core 签名后再计算并内嵌 SHA-256，签名配置纳入缓存输入 |
| `setup.dart` | Windows 委托 `scripts/windows/package.ps1` 构建、签名和打包，其余平台继续使用 distributor |
| `lib/common/constant.dart` | `appName`、helper 服务名、TUN 设备名、IPC socket / 管道前缀、helper socket 与协议头 |
| `lib/common/path.dart` | 内核可执行文件名、单实例锁文件名 |
| `lib/common/protocol.dart` | URL scheme `po0clash://` 与 Linux URL handler 桌面文件 |
| `lib/bootstrap.dart` / `lib/views/application_setting.dart` | 移除 Crashlytics 提示与开关 |

## 合并后

1. 重新生成代码与文案：`dart run build_runner build --delete-conflicting-outputs`、`dart run intl_utils:generate`。
2. 全局搜索上游新引入的 `FlClash`、`flclash`、`com.follow.clash`、Firebase 相关依赖，按上节规则处理。
3. `bash scripts/vps/verify.sh`。
4. 上游版本号变化不影响 po0-clash 的版本号；需要发版时按 [release.md](release.md) 递增自己的版本。
