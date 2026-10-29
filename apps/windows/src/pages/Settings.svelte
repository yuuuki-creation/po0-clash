<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../lib/core.svelte.js';
  import { t } from '../lib/i18n.js';
  import Switch from '../lib/Switch.svelte';

  let autostart = $state(false);

  $effect(() => {
    invoke('autostart_enabled').then((enabled) => (autostart = enabled));
  });

  async function setAutostart(enabled) {
    const previous = autostart;
    autostart = enabled;
    if ((await act('autostart', 'set_autostart', { enabled })) === undefined) autostart = previous;
  }

  async function exportDiagnostics() {
    const path = await act('diagnostics', 'export_diagnostics');
    if (path) notify(t('settings.exported', { path }));
  }
</script>

<section class="card row">
  <div class="grow-text">
    <span class="title">{t('settings.autostart')}</span>
    <span class="sub">{t('settings.autostartHint')}</span>
  </div>
  <Switch label={t('settings.autostart')} checked={autostart} disabled={app.busy.autostart} onchange={setAutostart} />
</section>

<section class="card row">
  <span class="title grow">{t('settings.diagnostics')}</span>
  <button type="button" disabled={app.busy.diagnostics} onclick={exportDiagnostics}>{t('settings.export')}</button>
</section>

<p class="version">po0-clash {app.version}</p>
