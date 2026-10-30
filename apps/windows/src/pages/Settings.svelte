<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../lib/core.svelte.js';
  import { t } from '../lib/i18n.js';
  import Page from '../lib/Page.svelte';
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

<Page id="settings">
  <h2 class="section-title">{t('settings.general')}</h2>
  <section class="card list">
    <div class="row">
      <div class="grow">
        <span class="strong">{t('settings.autostart')}</span>
        <span class="sub">{t('settings.autostartHint')}</span>
      </div>
      <Switch label={t('settings.autostart')} checked={autostart} disabled={app.busy.autostart} onchange={setAutostart} />
    </div>
    <div class="row">
      <div class="grow">
        <span class="strong">{t('settings.diagnostics')}</span>
        <span class="sub">{t('settings.diagnosticsHint')}</span>
      </div>
      <button type="button" class="pill" disabled={app.busy.diagnostics} onclick={exportDiagnostics}
        >{t('settings.export')}</button
      >
    </div>
  </section>

  <h2 class="section-title">{t('settings.about')}</h2>
  <section class="card list">
    <div class="row">
      <span class="grow">{t('settings.version')}</span>
      <span class="sub selectable">{app.version}</span>
    </div>
  </section>
</Page>
