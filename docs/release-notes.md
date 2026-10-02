po0-clash v6.0.0：支持 ggy 加白链接，加白请求改走内核专用直连入口，Android 开启加白后不再需要重启 VPN。

## 本次新增

- 支持 ggy（guguyun.com）加白链接：添加 token 时在「类型」里选择「ggy 加白链接」，粘贴 ggy 给的完整链接即可，与 po0 token 一起列出、一起自动加白
- 加白请求改走内核的专用直连入口：规则、全局模式和 TUN 都改变不了它的去向，加白的始终是本机真实出口，域名形式的加白地址也适用
- 专用入口每次启动自动选择空闲端口，并使用随机账号，其他程序无法借用它绕过代理
- Android 开启自动加白后不再需要重启 VPN
- 加白时如果挤掉了白名单里的旧记录，会写入日志
- 被限流时自动放慢检查频率

## 升级说明

- 从 5.x 直接覆盖安装即可，设置与 po0 token 全部保留

## 安装

- Windows：po0-clash-6.0.0-windows-amd64-setup.exe（安装包）或 .zip（免安装）
- macOS：curl -fsSL https://raw.githubusercontent.com/yuuuki-creation/po0-clash/main/scripts/install-macos.sh | bash
- Android：po0-clash-6.0.0-android-arm64-v8a.apk（主流机型），可与官方 FlClash 共存

## 已知限制

- ggy 加白链接没有只读查询：每个刷新间隔都会请求一次加白链接，「查询状态」对 ggy 同样会写入；日志里持续出现 evicted 说明白名单在被反复挤占，可调大刷新间隔
- Android 从最近任务划掉 po0-clash 后停止检查，重新打开应用即恢复
- 同时在用的网段超过白名单容量（po0 为 5 条，服务端已有的固定记录也占名额）时，各设备会互相挤占
- 与其他代理客户端同时开启系统代理或 TUN 会互相抢占，请只在一个应用里开启
- macOS 版本未经 Apple 公证，安装脚本会移除隔离属性；每次更新后首次开启虚拟网卡需重新输入管理员密码
