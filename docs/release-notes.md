po0-clash v6.1.0：ggy 加白独立成页，拥有自己的开关，固定每 11 秒加白一次。

## 本次新增

- ggy 加白独立为主导航里的一项，与 po0 并列（桌面端在侧边栏，手机端在底栏）：有自己的状态、「自动加白」开关和加白链接列表，与 po0 互不影响
- ggy 固定每 11 秒请求一次加白链接，不再跟随 po0 的刷新间隔；连续失败时自动放慢
- ggy 页面只保留「立即加白」：ggy 没有只读查询，「查询状态」与加白是同一个请求
- po0 的添加对话框只收 pgnfw_ token，不再有类型选择

## 升级说明

- 从 6.0.x 直接覆盖安装即可：原来混在 po0 列表里的 ggy 链接会自动移到 ggy 页面，并沿用原来的开关状态，无需重新添加
- 从 5.x 升级同样直接覆盖安装，设置与 po0 token 全部保留

## 安装

- Windows：po0-clash-6.1.0-windows-amd64-setup.exe（安装包）或 .zip（免安装）
- macOS：curl -fsSL https://raw.githubusercontent.com/yuuuki-creation/po0-clash/main/scripts/install-macos.sh | bash
- Android：po0-clash-6.1.0-android-arm64-v8a.apk（主流机型），可与官方 FlClash 共存

## 已知限制

- ggy 加白链接每次请求都会写入；日志里持续出现 evicted 说明白名单在被反复挤占
- Android 从最近任务划掉 po0-clash 后停止检查，重新打开应用即恢复
- 同时在用的网段超过白名单容量（po0 为 5 条，服务端已有的固定记录也占名额）时，各设备会互相挤占
- 与其他代理客户端同时开启系统代理或 TUN 会互相抢占，请只在一个应用里开启
- macOS 版本未经 Apple 公证，安装脚本会移除隔离属性；每次更新后首次开启虚拟网卡需重新输入管理员密码
