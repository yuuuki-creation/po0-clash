import { invoke } from '@tauri-apps/api/core';
import { notify } from './core.svelte.js';
import { createSettingsQueue } from './settings-queue.js';

export const settings = $state({ value: null });

const queue = createSettingsQueue({
  read: () => invoke('app_settings'),
  write: (value) => invoke('set_app_settings', { settings: value }),
  publish: (value) => (settings.value = value),
  onError: notify,
});

export const loadSettings = () => queue.load();

export const updateSettings = (patch) => queue.update($state.snapshot(patch));
