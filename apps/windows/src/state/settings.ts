import { proxy, snapshot } from 'valtio';
import { invoke } from '../ipc';
import { createSettingsQueue } from '../lib/settings-queue.js';
import { act, notify } from './core';

export const settings = proxy({ value: null as any });

const queue = createSettingsQueue({
  read: () => invoke('app_settings'),
  write: (value: any) => invoke('set_app_settings', { settings: value }),
  // valtio stores its nested proxies in the object it is given, and a proxy cannot be cloned for the next write.
  publish: (value: any) => (settings.value = structuredClone(value)),
  onError: notify,
});

export const loadSettings = () => queue.load();

export const updateSettings = (patch: Record<string, unknown>) => queue.update(patch);

export const engine = proxy({ options: null as any });

export async function loadOptions() {
  engine.options = await invoke('engine_options');
}

/** Applies `patch` to the engine options and writes the whole set back, as the core takes no partial update. */
export async function patchOptions(patch: Record<string, unknown>) {
  if (!engine.options) await loadOptions();
  Object.assign(engine.options, patch);
  await act('options', 'set_engine_options', { options: snapshot(engine.options) });
}

export const scripts = proxy({ list: [] as any[] });

export async function loadScripts() {
  scripts.list = await invoke('scripts');
}

export const toLines = (list?: string[]) => (list ?? []).join('\n');
export const fromLines = (text: string) =>
  text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

export const toPairs = (map?: Record<string, string>) =>
  Object.entries(map ?? {})
    .map(([key, value]) => `${key}=${value}`)
    .join('\n');
export const fromPairs = (text: string) =>
  Object.fromEntries(
    fromLines(text)
      .map((line) => line.split('='))
      .filter((parts) => parts.length >= 2 && parts[0].trim())
      .map(([key, ...rest]) => [key.trim(), rest.join('=').trim()]),
  );
