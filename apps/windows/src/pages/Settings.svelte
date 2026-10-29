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

<div class="group">
  <div class="row">
    <span class="grow">{t('settings.autostart')}</span>
    <Switch label={t('settings.autostart')} checked={autostart} disabled={app.busy.autostart} onchange={setAutostart} />
  </div>
</div>
<div class="footnote">{t('settings.autostartHint')}</div>

<div class="spacer"></div>
<div class="group">
  <div class="row">
    <span class="grow">{t('settings.diagnostics')}</span>
    <button type="button" class="text-button" disabled={app.busy.diagnostics} onclick={exportDiagnostics}
      >{t('settings.export')}</button
    >
  </div>
  <div class="row">
    <span class="grow">{t('settings.version')}</span>
    <span class="value">{app.version}</span>
  </div>
</div>
