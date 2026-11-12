import { proxy, subscribe } from 'valtio';
import { invoke } from '../ipc';
import { t } from '../lib/i18n.js';
import { createUpdateChecker } from '../lib/update-checker.js';
import { app, notify } from './core';
import { settings } from './settings';

export type Release = { version: string; url: string; notes: string };

export const update = proxy({ release: null as Release | null, checking: false, open: false, automatic: false });

const checker = createUpdateChecker({
  enabled: () => !!settings.value?.autoCheckUpdate,
  fetchRelease: async () => {
    update.checking = true;
    try { return await invoke<Release | null>('check_update'); }
    finally { update.checking = false; }
  },
  publish: (release: Release | null, userInitiated: boolean) => {
    update.release = release;
    if (release) {
      update.automatic = !userInitiated;
      update.open = userInitiated || update.open;
    } else if (userInitiated) {
      notify(t('update.latest'), '', 'success');
    }
  },
  failure: (error: unknown) => notify(t('update.failed'), String(error instanceof Error ? error.message : error)),
});

export const checkUpdate = (userInitiated: boolean) => checker.check(userInitiated);

export function startUpdateCheck() {
  let route = '';
  subscribe(app, () => {
    const next = [app.status?.engine.state, app.status?.routeMode, app.status?.currentNode, app.status?.profileId].join('|');
    if (next === route) return;
    route = next;
    if (app.status?.engine.state === 'running') void checker.check(false, true);
  });
  subscribe(settings, () => { void checker.check(); });
  window.addEventListener('online', () => { void checker.check(false, true); });
  setInterval(() => { void checker.check(); }, 5 * 60 * 1000);
  void checker.check();
}
