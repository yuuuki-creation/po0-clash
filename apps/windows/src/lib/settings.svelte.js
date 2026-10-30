import { invoke } from '@tauri-apps/api/core';
import { notify } from './core.svelte.js';

export const settings = $state({ value: null });

export async function loadSettings() {
  settings.value = await invoke('app_settings');
}

export async function updateSettings(patch) {
  const next = { ...$state.snapshot(settings.value), ...patch };
  settings.value = next;
  try {
    await invoke('set_app_settings', { settings: next });
  } catch (e) {
    notify(e);
  }
  await loadSettings();
}
