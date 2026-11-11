import en from './locales/en.js';
import ja from './locales/ja.js';
import ru from './locales/ru.js';
import zh from './locales/zh.js';

// Each page keeps its own strings in `locales/parts`; Node, which runs the tests, has no `import.meta.glob`.
let parts = {};
try {
  parts = import.meta.glob('./locales/parts/*.js', { eager: true });
} catch {
  parts = {};
}

const tables = { zh: { ...zh }, en: { ...en }, ja: { ...ja }, ru: { ...ru } };
for (const part of Object.values(parts)) {
  for (const [code, strings] of Object.entries(part.default)) Object.assign(tables[code], strings);
}
const tags = { zh: 'zh-CN', en: 'en', ja: 'ja', ru: 'ru' };

let table = tables.en;
let tag = 'en';

export function setLanguage(code) {
  table = tables[code] ?? tables.en;
  tag = tags[code] ?? 'en';
  document.documentElement.lang = tag;
}

export function t(key, vars = {}) {
  let text = table[key] ?? tables.en[key] ?? key;
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
  const digits = i === 0 || n >= 100 ? 0 : n >= 10 ? 1 : 2;
  return `${n.toFixed(digits)} ${units[i]}`;
}

export const formatRate = (n) => `${formatBytes(n)}/s`;

export function formatUsage(used, total) {
  const [value, unit] = formatBytes(used).split(' ');
  const whole = formatBytes(total);
  return whole.endsWith(` ${unit}`) ? `${value} / ${whole}` : `${value} ${unit} / ${whole}`;
}

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

export const delayTone = (delay) => (delay == null ? '' : delay === 0 ? 'bad' : delay < 600 ? 'good' : 'fair');

export function formatAgo(unix) {
  const seconds = Math.max(0, Math.round(Date.now() / 1000 - unix));
  if (seconds < 5) return t('ago.now');
  if (seconds < 60) return t('ago.seconds', { n: seconds });
  if (seconds < 3600) return t('ago.minutes', { n: Math.floor(seconds / 60) });
  if (seconds < 86400) return t('ago.hours', { n: Math.floor(seconds / 3600) });
  return t('ago.days', { n: Math.floor(seconds / 86400) });
}
