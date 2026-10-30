import { invoke } from '@tauri-apps/api/core';

export const scripts = $state({ list: [] });

export async function loadScripts() {
  scripts.list = await invoke('scripts');
}

export const lineCount = (script) => script.content.split('\n').length;
