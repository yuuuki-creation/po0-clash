import { invoke } from '@tauri-apps/api/core';
import { mount } from 'svelte';
import App from './App.svelte';
import './app.css';
import { app, init } from './lib/core.svelte.js';
import { setChinese } from './lib/i18n.js';
import { watchAppearance } from './lib/theme.svelte.js';

const info = await invoke('app_info');
setChinese(info.zh);
document.documentElement.classList.toggle('backdrop', info.backdrop);
app.version = info.version;

document.addEventListener('contextmenu', (event) => {
  if (!event.target.closest('input, textarea')) event.preventDefault();
});

watchAppearance();
mount(App, { target: document.getElementById('app') });
init();
