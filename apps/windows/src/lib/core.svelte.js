import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { t } from './i18n.js';

export const app = $state({
  version: '',
  page: 'dashboard',
  tool: null,
  sidebar: true,
  status: null,
  connectedAt: null,
  profiles: [],
  groups: [],
  whitelist: { enabled: false, entries: [] },
  traffic: { up: 0, down: 0 },
  history: [],
  memory: 0,
  totals: null,
  requestCount: 0,
  lan: null,
  exitIp: null,
  exitIpLoading: false,
  busy: {},
  notice: null,
});

export function notify(title, detail = '') {
  app.notice = { title: String(title), detail };
}

export async function act(key, command, args) {
  app.busy[key] = true;
  try {
    return await invoke(command, args);
  } catch (e) {
    notify(e);
    return undefined;
  } finally {
    delete app.busy[key];
  }
}

// The groups the core reports after a test come back without delays, so the last results are kept here.
const delays = new Map();

const withDelays = (group) => ({
  ...group,
  nodes: group.nodes.map((node) => ({ ...node, delay: delays.get(node.name) ?? node.delay ?? null })),
});

export async function testDelay(name) {
  const group = await act(`delay:${name}`, 'test_delay', { group: name });
  if (!group) return;
  for (const node of group.nodes) if (node.delay != null) delays.set(node.name, node.delay);
  app.groups = app.groups.map((g) => (g.name === name ? withDelays(group) : withDelays(g)));
}

export async function testNode(name) {
  const delay = await act(`node:${name}`, 'test_node_delay', { node: name });
  if (delay === undefined) return;
  delays.set(name, delay);
  app.groups = app.groups.map(withDelays);
}

async function loadGroups() {
  if (app.status?.engine.state !== 'running') {
    delays.clear();
    app.groups = [];
    return;
  }
  app.groups = (await invoke('groups')).map(withDelays);
}

const loaders = {
  status: async () => (app.status = await invoke('status')),
  profiles: async () => (app.profiles = await invoke('profiles')),
  groups: loadGroups,
  whitelist: async () => (app.whitelist = await invoke('whitelist')),
};

async function refresh(kind) {
  try {
    await loaders[kind]();
  } catch (e) {
    notify(e);
  }
}

let exitIpRequest = 0;

// Right after a start the engine may still be loading its nodes, so a failed lookup is retried a few times.
export async function refreshExitIp(attempt = 0) {
  const request = ++exitIpRequest;
  app.exitIpLoading = true;
  let result = null;
  try {
    result = await invoke('exit_ip');
  } catch {
    result = null;
  }
  if (request !== exitIpRequest) return;
  app.exitIp = result;
  app.exitIpLoading = false;
  if (!result && attempt < 3 && app.status?.engine.state === 'running') {
    setTimeout(() => request === exitIpRequest && refreshExitIp(attempt + 1), 3000);
  }
}

let routeKey = '';

async function refreshStatus() {
  await refresh('status');
  const s = app.status;
  if (!s) return;
  const engine = s.engine.state;
  if (engine !== 'running') app.connectedAt = null;
  else app.connectedAt ??= Date.now();
  const key = [engine, s.currentNode, s.mode, s.profileId].join('|');
  if (key === routeKey) return;
  const engineChanged = routeKey.split('|')[0] !== engine;
  routeKey = key;
  if (engineChanged) refresh('groups');
  if (engine === 'running' || engine === 'stopped') refreshExitIp();
}

let ticks = 0;

async function poll() {
  const tick = ticks++;
  if (tick % 10 === 0) invoke('intranet_ip').then((lan) => (app.lan = lan), () => (app.lan = null));
  if (document.hidden || app.status?.engine.state !== 'running') {
    if (app.history.length || app.totals) {
      Object.assign(app, { traffic: { up: 0, down: 0 }, history: [], memory: 0, totals: null, requestCount: 0 });
    }
    return;
  }
  try {
    const [history, memory] = await Promise.all([invoke('traffic_history'), invoke('memory')]);
    Object.assign(app, { history, memory, traffic: history.at(-1) ?? { up: 0, down: 0 } });
    if (tick % 2 === 0) {
      const [connections, requests] = await Promise.all([invoke('connections'), invoke('requests')]);
      Object.assign(app, { totals: connections, requestCount: requests.length });
    }
  } catch {
    Object.assign(app, { traffic: { up: 0, down: 0 }, history: [], memory: 0 });
  }
}

function explainLaunch(notice) {
  if (!notice) return;
  if (notice.cleared && notice.profileName) {
    const profile = app.profiles.find((p) => p.name === notice.profileName);
    const name = profile?.kind === 'links' ? t('profiles.links') : notice.profileName;
    notify(t('launch.crashed'), t('launch.cleared', { name }));
  } else {
    notify(t('launch.unfinished'), t('launch.skipped'));
  }
}

export async function init() {
  await listen('core-change', ({ payload }) => {
    if (payload === 'status') return refreshStatus();
    refresh(payload);
    if (payload === 'groups') refreshStatus();
    if (payload === 'profiles') refresh('groups');
  });
  await listen('shell-error', ({ payload }) => notify(payload));
  await Promise.all([refreshStatus(), refresh('profiles'), refresh('whitelist')]);
  explainLaunch(await invoke('launch_notice'));
  poll();
  setInterval(poll, 1000);
}
