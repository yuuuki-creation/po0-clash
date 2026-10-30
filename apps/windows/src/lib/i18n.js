const zh = {
  'page.dashboard': '仪表盘',
  'page.proxies': '代理',
  'page.profiles': '订阅',
  'page.whitelist': '加白',
  'page.settings': '设置',
  'home.connect': '连接',
  'home.connecting': '正在连接…',
  'home.disconnect': '断开',
  'home.reconnect': '重新连接',
  'home.failed': '连接失败',
  'home.speed': '速率',
  'home.exitIp': '出口 IP',
  'home.refresh': '刷新',
  'home.node': '当前节点',
  'home.mode': '模式',
  'home.route': '接管方式',
  'home.profile': '订阅',
  'home.addProfile': '添加订阅…',
  'home.whitelist': '自动加白',
  'home.whitelisted': '{applied} / {total} 已加白',
  'home.noEntries': '还没有 token 或链接',
  'mode.rule': '规则',
  'mode.global': '全局',
  'mode.direct': '直连',
  'route.tun': '虚拟网卡',
  'route.systemProxy': '系统代理',
  'proxies.testAll': '全部测速',
  'proxies.test': '测试延迟',
  'proxies.timeout': '超时',
  'proxies.direct': '直连模式',
  'proxies.directHint': '流量直接出站，不使用代理。',
  'proxies.empty': '没有策略组',
  'proxies.emptyHint': '选好订阅并连接后，这里会显示它的策略组。',
  'profiles.add': '添加订阅',
  'profiles.addEllipsis': '添加订阅…',
  'profiles.url': '订阅链接',
  'profiles.urlPlaceholder': 'https://…',
  'profiles.empty': '没有订阅',
  'profiles.emptyHint': '添加订阅链接，或导入分享链接。',
  'profiles.use': '使用此订阅',
  'profiles.update': '更新',
  'profiles.delete': '删除',
  'profiles.confirmDelete': '删除「{name}」？',
  'profiles.links': '导入的节点',
  'profiles.used': '已用 {used} / {total}',
  'profiles.expire': '{date} 到期',
  'profiles.updated': '{time} 更新',
  'profiles.import': '导入分享链接',
  'profiles.importEllipsis': '导入分享链接…',
  'profiles.importHint': '粘贴一条或多条 vless://、vmess://、ss://、trojan://、hysteria2:// 等分享链接，每行一条。',
  'profiles.importButton': '导入',
  'profiles.imported': '已导入 {count} 个节点',
  'whitelist.enabled': '自动加白',
  'whitelist.hint': '只要 po0-clash 开着，无论是否连接，都会把这台电脑的真实出口 IP 保持在 po0 与 ggy 白名单中。po0 每 5 秒、ggy 每 11 秒检查一次。',
  'whitelist.entries': 'token 与链接',
  'whitelist.now': '立即检查',
  'whitelist.empty': '没有 token 或链接',
  'whitelist.emptyHint': '添加 po0 token 或 ggy 加白链接。',
  'whitelist.addEllipsis': '添加…',
  'whitelist.addTitle': '添加加白项',
  'whitelist.add': '添加',
  'whitelist.textPlaceholder': '粘贴 po0 token 或 ggy 加白链接，每行一条。',
  'whitelist.namePlaceholder': '名称（可选）',
  'whitelist.added': '已添加 {count} 条',
  'whitelist.remove': '移除',
  'whitelist.confirmRemove': '移除「{name}」？',
  'whitelist.pending': '等待首次检查',
  'outcome.applied': '已加白',
  'outcome.notApplied': '未加白',
  'outcome.disabled': '已停用',
  'outcome.rejected': '被拒绝',
  'outcome.error': '出错',
  'settings.general': '通用',
  'settings.autostart': '开机自启',
  'settings.autostartHint': '登录 Windows 后在后台启动，不弹出管理员授权；退出时处于连接状态的话会自动重新连接。',
  'settings.diagnostics': '诊断日志',
  'settings.diagnosticsHint': '把应用、内核与引擎日志保存为文本文件，便于排查问题。',
  'settings.export': '导出…',
  'settings.exported': '已保存到 {path}',
  'settings.about': '关于',
  'settings.version': '版本',
  'common.cancel': '取消',
  'common.dismiss': '关闭',
};

const en = {
  'page.dashboard': 'Dashboard',
  'page.proxies': 'Proxies',
  'page.profiles': 'Subscriptions',
  'page.whitelist': 'Whitelist',
  'page.settings': 'Settings',
  'home.connect': 'Connect',
  'home.connecting': 'Connecting…',
  'home.disconnect': 'Disconnect',
  'home.reconnect': 'Reconnect',
  'home.failed': 'Connection failed',
  'home.speed': 'Speed',
  'home.exitIp': 'Exit IP',
  'home.refresh': 'Refresh',
  'home.node': 'Current node',
  'home.mode': 'Mode',
  'home.route': 'Route',
  'home.profile': 'Subscription',
  'home.addProfile': 'Add subscription…',
  'home.whitelist': 'Auto whitelist',
  'home.whitelisted': '{applied} of {total} whitelisted',
  'home.noEntries': 'No tokens or links yet',
  'mode.rule': 'Rule',
  'mode.global': 'Global',
  'mode.direct': 'Direct',
  'route.tun': 'TUN',
  'route.systemProxy': 'System proxy',
  'proxies.testAll': 'Test all',
  'proxies.test': 'Test delay',
  'proxies.timeout': 'Timeout',
  'proxies.direct': 'Direct mode',
  'proxies.directHint': 'Traffic goes out directly, so no proxy is used.',
  'proxies.empty': 'No proxy groups',
  'proxies.emptyHint': 'Connect with a subscription to load its proxy groups.',
  'profiles.add': 'Add subscription',
  'profiles.addEllipsis': 'Add subscription…',
  'profiles.url': 'Subscription URL',
  'profiles.urlPlaceholder': 'https://…',
  'profiles.empty': 'No subscriptions',
  'profiles.emptyHint': 'Add a subscription URL or import share links.',
  'profiles.use': 'Use this subscription',
  'profiles.update': 'Update',
  'profiles.delete': 'Delete',
  'profiles.confirmDelete': 'Delete “{name}”?',
  'profiles.links': 'Imported nodes',
  'profiles.used': '{used} of {total} used',
  'profiles.expire': 'Expires {date}',
  'profiles.updated': 'Updated {time}',
  'profiles.import': 'Import share links',
  'profiles.importEllipsis': 'Import share links…',
  'profiles.importHint': 'Paste one or more links such as vless://, vmess://, ss://, trojan:// or hysteria2://, one per line.',
  'profiles.importButton': 'Import',
  'profiles.imported': 'Imported {count} nodes',
  'whitelist.enabled': 'Auto whitelist',
  'whitelist.hint': "Keeps this PC's real exit IP on the po0 and ggy whitelists while po0-clash is open, connected or not. Checks po0 every 5 s and ggy every 11 s.",
  'whitelist.entries': 'Tokens and links',
  'whitelist.now': 'Check now',
  'whitelist.empty': 'No tokens or links',
  'whitelist.emptyHint': 'Add a po0 token or a ggy whitelist link.',
  'whitelist.addEllipsis': 'Add…',
  'whitelist.addTitle': 'Add to whitelist',
  'whitelist.add': 'Add',
  'whitelist.textPlaceholder': 'Paste po0 tokens or ggy whitelist links, one per line.',
  'whitelist.namePlaceholder': 'Name (optional)',
  'whitelist.added': 'Added {count}',
  'whitelist.remove': 'Remove',
  'whitelist.confirmRemove': 'Remove “{name}”?',
  'whitelist.pending': 'Waiting for the first check',
  'outcome.applied': 'Whitelisted',
  'outcome.notApplied': 'Not whitelisted',
  'outcome.disabled': 'Disabled',
  'outcome.rejected': 'Rejected',
  'outcome.error': 'Error',
  'settings.general': 'General',
  'settings.autostart': 'Launch at login',
  'settings.autostartHint': 'Starts in the background after you sign in, without a UAC prompt, and reconnects if it was connected when it quit.',
  'settings.diagnostics': 'Diagnostics log',
  'settings.diagnosticsHint': 'Saves the app, core and engine logs to a text file for troubleshooting.',
  'settings.export': 'Export…',
  'settings.exported': 'Saved to {path}',
  'settings.about': 'About',
  'settings.version': 'Version',
  'common.cancel': 'Cancel',
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

export function formatElapsed(ms) {
  const seconds = Math.max(0, Math.floor(ms / 1000));
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(Math.floor(seconds / 3600))}:${pad(Math.floor(seconds / 60) % 60)}:${pad(seconds % 60)}`;
}

export const formatDelay = (delay) => (delay == null ? '' : delay === 0 ? t('proxies.timeout') : `${delay} ms`);

export const delayTone = (delay) => (delay == null ? '' : delay === 0 ? 'bad' : delay < 300 ? 'good' : 'fair');
