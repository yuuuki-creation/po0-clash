import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';

export const app = $state({
  version: '',
  status: null,
  profiles: [],
  groups: [],
  whitelist: { enabled: false, entries: [] },
  traffic: { up: 0, down: 0 },
  exitIp: null,
  exitIpLoading: false,
  busy: {},
  notice: null,
});

let noticeTimer;

export function notify(text, error = false) {
  app.notice = { text: String(text), error };
  clearTimeout(noticeTimer);
  noticeTimer = setTimeout(() => (app.notice = null), error ? 8000 : 3000);
}

export async function act(key, command, args) {
  app.busy[key] = true;
  try {
    return await invoke(command, args);
  } catch (e) {
    notify(e, true);
    return undefined;
  } finally {
    delete app.busy[key];
  }
}

const loaders = {
  status: async () => (app.status = await invoke('status')),
  profiles: async () => (app.profiles = await invoke('profiles')),
  groups: async () => (app.groups = app.status?.engine.state === 'running' ? await invoke('groups') : []),
  whitelist: async () => (app.whitelist = await invoke('whitelist')),
};

async function refresh(kind) {
  try {
    await loaders[kind]();
  } catch (e) {
    notify(e, true);
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
  const key = [engine, s.currentNode, s.mode, s.profileId].join('|');
  if (key === routeKey) return;
  const engineChanged = routeKey.split('|')[0] !== engine;
  routeKey = key;
  if (engineChanged) refresh('groups');
  if (engine === 'running' || engine === 'stopped') refreshExitIp();
}

async function pollTraffic() {
  if (document.hidden || app.status?.engine.state !== 'running') {
    if (app.traffic.up || app.traffic.down) app.traffic = { up: 0, down: 0 };
    return;
  }
  try {
    app.traffic = await invoke('traffic');
  } catch {
    app.traffic = { up: 0, down: 0 };
  }
}

export async function init() {
  await listen('core-change', ({ payload }) => {
    if (payload === 'status') return refreshStatus();
    refresh(payload);
    if (payload === 'groups') refreshStatus();
    if (payload === 'profiles') refresh('groups');
  });
  await listen('shell-error', ({ payload }) => notify(payload, true));
  await Promise.all([refreshStatus(), refresh('profiles'), refresh('whitelist')]);
  setInterval(pollTraffic, 1000);
}
