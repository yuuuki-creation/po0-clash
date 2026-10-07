po0-clash v6.1.1：修复订阅更新、设置损坏、排除 Wi-Fi 切换和延迟徽章等问题。

## 本次修复

- 订阅返回的流量信息头末尾带多余的分号或不规范片段时，订阅不再永远更新失败
- 升级后某一项设置（网络、VPN、代理页样式、窗口、内核设置）无法识别时，只把这一项恢复为默认值，不再提示「本地数据损坏」并强制重置全部数据
- 连上或离开被排除的 Wi-Fi 时，不再覆盖你刚点下的停止：停止之后不会被稍晚触发的启动重新拉起
- 延迟徽章、IP 检测和代理卡上的「超时」按界面语言显示，不再固定为英文 Timeout
- Android 内核在启动或停止虚拟网卡时遇到内部错误，现在会记录日志并报告失败，不再让整个应用直接退出

## 升级说明

- 从 6.1.0 或更早版本直接覆盖安装即可，设置、po0 token 与 ggy 加白链接全部保留

## 安装

- Windows：po0-clash-6.1.1-windows-amd64-setup.exe（安装包）或 .zip（免安装）
- macOS：curl -fsSL https://raw.githubusercontent.com/yuuuki-creation/po0-clash/main/scripts/install-macos.sh | bash
- Android：po0-clash-6.1.1-android-arm64-v8a.apk（主流机型），可与官方 FlClash 共存

## 已知限制

- ggy 加白链接每次请求都会写入；日志里持续出现 evicted 说明白名单在被反复挤占
- Android 从最近任务划掉 po0-clash 后停止检查，重新打开应用即恢复
- 同时在用的网段超过白名单容量（po0 为 5 条，服务端已有的固定记录也占名额）时，各设备会互相挤占
- 与其他代理客户端同时开启系统代理或 TUN 会互相抢占，请只在一个应用里开启
- macOS 版本未经 Apple 公证，安装脚本会移除隔离属性；每次更新后首次开启虚拟网卡需重新输入管理员密码
