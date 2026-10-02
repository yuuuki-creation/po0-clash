po0-clash v6.0.1：修复添加 token 时类型菜单悬空、样式与应用不一致。

## 本次修复

- 添加或编辑 token 时，「类型」菜单改为紧贴在选择栏下方展开、与选择栏同宽，使用与应用其他菜单一致的玻璃样式，当前选项打勾；不再悬浮在对话框中间，也不再是另一套默认样式

## 升级说明

- 从 6.0.0 或 5.x 直接覆盖安装即可，设置、po0 token 与 ggy 加白链接全部保留

## 安装

- Windows：po0-clash-6.0.1-windows-amd64-setup.exe（安装包）或 .zip（免安装）
- macOS：curl -fsSL https://raw.githubusercontent.com/yuuuki-creation/po0-clash/main/scripts/install-macos.sh | bash
- Android：po0-clash-6.0.1-android-arm64-v8a.apk（主流机型），可与官方 FlClash 共存

## 已知限制

- ggy 加白链接没有只读查询：每个刷新间隔都会请求一次加白链接，「查询状态」对 ggy 同样会写入；日志里持续出现 evicted 说明白名单在被反复挤占，可调大刷新间隔
- Android 从最近任务划掉 po0-clash 后停止检查，重新打开应用即恢复
- 同时在用的网段超过白名单容量（po0 为 5 条，服务端已有的固定记录也占名额）时，各设备会互相挤占
- 与其他代理客户端同时开启系统代理或 TUN 会互相抢占，请只在一个应用里开启
- macOS 版本未经 Apple 公证，安装脚本会移除隔离属性；每次更新后首次开启虚拟网卡需重新输入管理员密码
