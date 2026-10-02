po0-clash v5.2.2：修复 Windows 上 po0 加白报证书错误，修正悬浮按钮与工具栏按钮错位。

## 本次修复

- 修复 Windows 新装或刚重置的系统上 po0 加白报「CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate」：应用改为自带 Let's Encrypt 根证书，不再依赖系统是否已下载该证书，也不必再重启应用；Android 7.0 同样修复
- 修复应用排除、日志、请求页的悬浮按钮跑到屏幕中间的问题，恢复停在右下角
- 修复工具栏按钮高低不齐、间距不均：文字按钮与图标按钮统一高度，Android 应用排除页的「保存」与「⋮」不再挤在一起，规则、脚本、覆写等编辑页的按钮两侧留白一致

## 升级说明

- 从 5.2.x 直接覆盖安装即可，设置全部保留

## 安装

- Windows：po0-clash-5.2.2-windows-amd64-setup.exe（安装包）或 .zip（免安装）
- macOS：curl -fsSL https://raw.githubusercontent.com/yuuuki-creation/po0-clash/main/scripts/install-macos.sh | bash
- Android：po0-clash-5.2.2-android-arm64-v8a.apk（主流机型），可与官方 FlClash 共存

## 已知限制

- Android 首次开启自动加白后需重启一次 VPN，直连路由才会生效
- Android 从最近任务划掉 po0-clash 后停止检查，重新打开应用即恢复
- 同时在用的网段超过白名单容量（5 条，服务端已有的固定记录也占名额）时，各设备会互相挤占
- 与其他代理客户端同时开启系统代理或 TUN 会互相抢占，请只在一个应用里开启
- macOS 版本未经 Apple 公证，安装脚本会移除隔离属性；每次更新后首次开启虚拟网卡需重新输入管理员密码
