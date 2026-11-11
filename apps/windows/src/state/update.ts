import { proxy } from 'valtio';
import { invoke, platform } from '../ipc';
import { t } from '../lib/i18n.js';
import { newestAbove } from '../lib/version.js';
import { app, notify } from './core';
import { settings } from './settings';

const RELEASES = 'https://api.github.com/repos/yuuuki-creation/po0-clash/releases?per_page=30';

export type Release = { version: string; url: string; notes: string };

export const update = proxy({ release: null as Release | null, checking: false, open: false, automatic: false });

// The Windows shell has no update command, so the page asks GitHub itself; macOS goes through the core.
async function fetchRelease(): Promise<Release | null> {
  if (platform !== 'windows') return invoke<Release | null>('check_update');
  const response = await fetch(RELEASES, { headers: { Accept: 'application/vnd.github+json' } });
  if (!response.ok) throw new Error(`GitHub ${response.status}`);
  return newestAbove(app.version, await response.json());
}

export async function checkUpdate(userInitiated: boolean) {
  if (update.checking) return;
  update.checking = true;
  try {
    const release = await fetchRelease();
    update.release = release;
    if (release) {
      update.automatic = !userInitiated;
      update.open = userInitiated || update.open;
    } else if (userInitiated) {
      notify(t('update.latest'), '', 'success');
    }
  } catch (error) {
    if (userInitiated) notify(t('update.failed'), String(error instanceof Error ? error.message : error));
  } finally {
    update.checking = false;
  }
}

export function startUpdateCheck() {
  // The macOS shell runs its own check at launch and prompts natively.
  if (platform !== 'macos' && settings.value?.autoCheckUpdate) checkUpdate(false);
}
