import { invoke } from '@tauri-apps/api/core';
import { mount } from 'svelte';
import App from './App.svelte';
import './app.css';
import { app, init } from './lib/core.svelte.js';
import { setLanguage } from './lib/i18n.js';
import { loadSettings } from './lib/settings.svelte.js';
import { watchAppearance } from './lib/theme.svelte.js';

const [info] = await Promise.all([invoke('app_info'), loadSettings()]);
setLanguage(info.language);
document.documentElement.classList.toggle('backdrop', info.backdrop);
app.version = info.version;

document.addEventListener('contextmenu', (event) => {
  if (!event.target.closest('input, textarea')) event.preventDefault();
});

watchAppearance();
mount(App, { target: document.getElementById('app') });
init();
