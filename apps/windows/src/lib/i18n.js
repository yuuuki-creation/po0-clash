const zh = {
  'tab.home': '连接',
  'tab.proxies': '节点',
  'tab.profiles': '订阅',
  'tab.whitelist': '加白',
  'tab.settings': '设置',
  'engine.stopped': '未连接',
  'engine.starting': '正在连接…',
  'engine.running': '已连接',
  'engine.failed': '连接失败',
  'home.connect': '连接',
  'home.disconnect': '断开',
  'home.reconnect': '重新连接',
  'home.status': '状态',
  'home.node': '当前节点',
  'home.exitIp': '出口 IP',
  'home.upload': '上传',
  'home.download': '下载',
  'home.mode': '代理模式',
  'home.route': '接管方式',
  'mode.rule': '规则',
  'mode.global': '全局',
  'mode.direct': '直连',
  'route.tun': '虚拟网卡',
  'route.systemProxy': '系统代理',
  'proxies.notRunning': '连接后可以选择节点。',
  'proxies.empty': '没有策略组。',
  'proxies.test': '测速',
  'proxies.timeout': '超时',
  'profiles.title': '订阅',
  'profiles.add': '添加',
  'profiles.urlPlaceholder': '订阅链接 https://…',
  'profiles.empty': '还没有订阅。',
  'profiles.use': '使用',
  'profiles.inUse': '使用中',
  'profiles.update': '更新',
  'profiles.delete': '删除',
  'profiles.confirmDelete': '确认删除',
  'profiles.links': '导入的节点',
  'profiles.used': '已用 {used} / {total}',
  'profiles.expire': '{date} 到期',
  'profiles.updated': '{time} 更新',
  'profiles.import': '导入分享链接',
  'profiles.importPlaceholder': '每行一个分享链接：vless://、ss://、trojan://…',
  'profiles.importButton': '导入',
  'profiles.imported': '已导入 {count} 个节点',
  'whitelist.enabled': '自动加白',
  'whitelist.hint': 'po0 每 5 秒、ggy 每 11 秒检查一次，代理关闭时也会运行。',
  'whitelist.entries': 'po0 token 与 ggy 链接',
  'whitelist.now': '立即检查',
  'whitelist.empty': '还没有 token 或链接。',
  'whitelist.add': '添加',
  'whitelist.textPlaceholder': 'po0 token 或 ggy 加白链接，可以一次粘贴多个',
  'whitelist.namePlaceholder': '名称（可选）',
  'whitelist.added': '已添加 {count} 条',
  'whitelist.remove': '移除',
  'whitelist.pending': '尚未检查',
  'outcome.applied': '已加白',
  'outcome.notApplied': '未加白',
  'outcome.disabled': '已停用',
  'outcome.rejected': '被拒绝',
  'outcome.error': '出错',
  'settings.autostart': '开机自启',
  'settings.autostartHint': '登录 Windows 后在后台启动，不弹出管理员授权；退出时处于连接状态的话会自动重新连接。',
  'settings.diagnostics': '诊断日志',
  'settings.export': '导出',
  'settings.exported': '已保存到 {path}',
  'settings.version': '版本',
  'common.dismiss': '关闭',
};

const en = {
  'tab.home': 'Connection',
  'tab.proxies': 'Nodes',
  'tab.profiles': 'Profiles',
  'tab.whitelist': 'Whitelist',
  'tab.settings': 'Settings',
  'engine.stopped': 'Disconnected',
  'engine.starting': 'Connecting…',
  'engine.running': 'Connected',
  'engine.failed': 'Connection failed',
  'home.connect': 'Connect',
  'home.disconnect': 'Disconnect',
  'home.reconnect': 'Reconnect',
  'home.status': 'Status',
  'home.node': 'Node',
  'home.exitIp': 'Exit IP',
  'home.upload': 'Upload',
  'home.download': 'Download',
  'home.mode': 'Mode',
  'home.route': 'Route traffic via',
  'mode.rule': 'Rule',
  'mode.global': 'Global',
  'mode.direct': 'Direct',
  'route.tun': 'TUN',
  'route.systemProxy': 'System proxy',
  'proxies.notRunning': 'Connect to choose nodes.',
  'proxies.empty': 'No proxy groups.',
  'proxies.test': 'Test',
  'proxies.timeout': 'Timeout',
  'profiles.title': 'Subscriptions',
  'profiles.add': 'Add',
  'profiles.urlPlaceholder': 'Subscription URL https://…',
  'profiles.empty': 'No subscriptions yet.',
  'profiles.use': 'Use',
  'profiles.inUse': 'In use',
  'profiles.update': 'Update',
  'profiles.delete': 'Delete',
  'profiles.confirmDelete': 'Confirm',
  'profiles.links': 'Imported nodes',
  'profiles.used': '{used} of {total} used',
  'profiles.expire': 'Expires {date}',
  'profiles.updated': 'Updated {time}',
  'profiles.import': 'Import share links',
  'profiles.importPlaceholder': 'One share link per line: vless://, ss://, trojan://…',
  'profiles.importButton': 'Import',
  'profiles.imported': 'Imported {count} nodes',
  'whitelist.enabled': 'Auto whitelist',
  'whitelist.hint': 'Checks po0 every 5 s and ggy every 11 s, also while the proxy is off.',
  'whitelist.entries': 'po0 tokens and ggy links',
  'whitelist.now': 'Check now',
  'whitelist.empty': 'No tokens or links yet.',
  'whitelist.add': 'Add',
  'whitelist.textPlaceholder': 'po0 tokens or ggy whitelist links, several at once is fine',
  'whitelist.namePlaceholder': 'Name (optional)',
  'whitelist.added': 'Added {count}',
  'whitelist.remove': 'Remove',
  'whitelist.pending': 'Not checked yet',
  'outcome.applied': 'Whitelisted',
  'outcome.notApplied': 'Not whitelisted',
  'outcome.disabled': 'Disabled',
  'outcome.rejected': 'Rejected',
  'outcome.error': 'Error',
  'settings.autostart': 'Launch at login',
  'settings.autostartHint': 'Starts in the background after you sign in, without a UAC prompt, and reconnects if it was connected when it quit.',
  'settings.diagnostics': 'Diagnostics log',
  'settings.export': 'Export',
  'settings.exported': 'Saved to {path}',
  'settings.version': 'Version',
  'common.dismiss': 'Dismiss',
};

let table = en;
let tag = 'en';

export function setChinese(chinese) {
  table = chinese ? zh : en;
  tag = chinese ? 'zh-CN' : 'en';
  document.documentElement.lang = tag;
}

export function t(key, vars = {}) {
  let text = table[key] ?? key;
  for (const [name, value] of Object.entries(vars)) text = text.replace(`{${name}}`, value);
  return text;
}

export function formatBytes(n) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024;
    i++;
  }
  return `${n.toFixed(i === 0 || n >= 100 ? 0 : 1)} ${units[i]}`;
}

export const formatRate = (n) => `${formatBytes(n)}/s`;

export const formatDate = (unix) => new Date(unix * 1000).toLocaleDateString(tag);

export function formatTime(unix) {
  const date = new Date(unix * 1000);
  const sameDay = date.toDateString() === new Date().toDateString();
  return sameDay ? date.toLocaleTimeString(tag) : date.toLocaleString(tag);
}
