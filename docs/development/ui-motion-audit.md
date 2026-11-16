# 8.2.0 界面复核

基线是已发布的 8.1.1。桌面参考 Clash Verge Rev 2.5.10（`c83f7ad`），Android 参考 FlClash 0.9.3（`be84736`）及其锁定的 prism_ui（`63450c0`）。核对范围是现有功能的呈现与交互，不增加参考程序独有的内核功能。

## 桌面：Windows / macOS 共用界面

| 项目 | 发现与处理 | 验证入口 |
|---|---|---|
| 导航、标题、页面切换 | 参考实现直接切页；删除额外的上滑淡入及无效设置 | `motion.spec.ts` |
| 窄窗、宽窗、浅色、深色 | 八个页面逐项检查溢出和脚本异常 | `desktop.spec.ts` |
| 侧栏收起、切页 | 继续使用 MUI 导航选择与悬停反馈，不额外移动指示器 | 源码核对 |
| 侧栏流量图 | 原来逐帧跳换折线；改为 30 点平滑曲线和每次采样 1 秒平移，空数据不启动动画 | `motion.spec.ts` |
| 图表缩放、主题 | 监听尺寸变化，重绘画布；侧栏颜色从当前主题读取 | 两套浏览器与主题截图 |
| 首页连接、模式、路由 | 保留 MUI 开关、按钮反馈和内核忙碌状态 | `desktop.spec.ts` |
| 代理分组展开、搜索、排序、定位 | 缩小组工具图标；定位、测速和排序先展开组；保留虚拟列表即时重排 | 源码核对及 `desktop.spec.ts` |
| 节点选择与测速 | 保留选中边线、悬停检查按钮和测速等待状态 | `desktop.spec.ts` |
| 订阅卡片、拖动排序、更新 | 保留旋转更新图标与拖动反馈；补齐卡片键盘选择 | 源码核对 |
| 设置、订阅、覆写、脚本弹窗 | 关闭时父组件过早卸载；现在等 MUI 退出结束，内容不提前清空 | `DialogPresence`、`motion.spec.ts` |
| 嵌套弹窗 | 子弹窗的退出不能触发父弹窗卸载；各自管理退出与焦点 | `motion.spec.ts` |
| 配置菜单 | 关闭时保留菜单条目和锚点，避免退出途中突然缩成空框 | `Profiles.tsx` |
| 通知、连接详情 | 退出期间保留内容，避免空白闪烁 | `Layout.tsx`、`ConnectionDetail.tsx` |
| 连接、规则、日志搜索 | 保留即时过滤；补齐大小写、完整词、正则按钮的键盘操作 | 源码核对 |
| 大字号与弹窗 | 限制内容宽度，保持 Escape 关闭和焦点归还 | `motion.spec.ts` |
| 减少动态效果 | 同时处理 CSS、MUI 退出计时与 Canvas Web Animations；运行时更改立即生效 | `motion.spec.ts` |

## Android

| 项目 | 发现与处理 | 验证入口 |
|---|---|---|
| 标签页切换 | 原来 300 毫秒缩放淡入；改为参考实现的 220 毫秒原位交叉淡化，宽屏直接切页 | `MotionTest` |
| 底栏点击、拖动、取消 | 原来拖过即切页；现在只预览滑块位置，松手提交，取消返回当前项 | `MotionTest` |
| 导航条目变化 | 编辑仪表盘、移除配置后当前页可能不再可见；回到仪表盘 | `App.kt` |
| 开关 | 原来使用默认 M3；按 prism_ui 补齐实心轨道、300 毫秒滑动、伸缩、按压抬起和拖动 | `MotionTest` |
| 连接按钮 | 补齐 450 毫秒缓动形变、40 度旋转、按压回弹、播放/暂停图标插值，启动仍可取消 | `CurrentOutboundCard.kt`、`MotionTest` |
| 状态卡装饰 | 随连接状态旋转 30 度并放大 12%，保持显示动画与连接意图分离 | `CurrentOutboundCard.kt` |
| 分组展开、节点选中 | 箭头旋转，选中标记淡入缩放；保留虚拟列表的条目位移动画 | `ProxiesScreen.kt` |
| 菜单 | 首次创建时没有进入过渡；用独立状态播放 450 毫秒弹簧进入和收缩退出，退出期间保留遮挡层 | `Overlays.kt` |
| 确认框 | 原来由 0.85 倍放大；按参考改为 1.2 倍缩小进入，退出只淡化 | `Overlays.kt` |
| 底部表单、返回 | 表单改为 500 毫秒临界阻尼弹簧；二级页面用全宽推入和底页 30% 视差，保留预测返回 | `Motion.kt`、`Overlays.kt` |
| 减少动态效果 | 监听系统设置变化；切页、开关、菜单、确认框立即完成，等待指示静止 | `MotionTest` |

## 验证范围

桌面测试覆盖 Chromium 和 WebKit，并保留浅深色页面截图。[Windows 安装版对照](https://github.com/yuuuki-creation/po0-clash/actions/runs/43925577518)在同一机器上安装官方 Clash Verge Rev 与本次安装包，采集七个共有页面。官方截图不含系统标题栏，本应用截图含自绘标题栏，核对内容区时扣除这部分高度。Android 的 Compose 测试在 API 35 模拟器执行，覆盖真实指针拖动、取消、开关语义、切页中间态和静止等待状态。发布流水线另跑 Windows 安装包冒烟测试，macOS 的安装与引擎检查沿用 `native-macos.yaml`。

这些检查不等于逐像素、逐帧一致：Compose 的字体光栅化、曲线边缘、系统窗口行为与 Flutter 有差异；macOS 菜单栏原生面板也不属于共用网页。真机触感、各系统刷新率以及平台授权弹窗仍需实际设备复核。

参考源码：[Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev/tree/v2.5.10/src)、[FlClash](https://github.com/chen08209/FlClash/tree/v0.9.3/lib)、[prism_ui](https://github.com/chen08209/prism_ui/tree/63450c0ac0e8e1b2c0f3ed4ad7926dc94e083185/lib)。
