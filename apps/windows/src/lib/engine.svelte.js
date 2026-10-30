import { invoke } from '@tauri-apps/api/core';
import { act } from './core.svelte.js';

export const engine = $state({ options: null });

export async function loadOptions() {
  engine.options = await invoke('engine_options');
}

export async function saveOptions() {
  if (engine.options) await act('options', 'set_engine_options', { options: $state.snapshot(engine.options) });
}

export const toLines = (list) => (list ?? []).join('\n');
export const fromLines = (text) =>
  text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

export const toPairs = (map) =>
  Object.entries(map ?? {})
    .map(([key, value]) => `${key}=${value}`)
    .join('\n');
export const fromPairs = (text) =>
  Object.fromEntries(
    fromLines(text)
      .map((line) => line.split('='))
      .filter((parts) => parts.length >= 2 && parts[0].trim())
      .map(([key, ...rest]) => [key.trim(), rest.join('=').trim()]),
  );
