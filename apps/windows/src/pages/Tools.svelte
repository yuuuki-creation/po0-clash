<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../lib/core.svelte.js';
  import { t } from '../lib/i18n.js';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import Page from '../lib/Page.svelte';
  import Switch from '../lib/Switch.svelte';

  // FlClash's tools page; entries without core support yet open a placeholder (docs/development/native-feature-parity.md).
  const sections = [
    {
      id: 'settings',
      entries: [
        ['language', 'language'],
        ['appearance', 'appearance'],
        ['application', 'window'],
        ['hotkeys', 'keyboard'],
      ],
    },
    {
      id: 'network',
      entries: [
        ['basic', 'sliders'],
        ['networkSettings', 'network'],
        ['dns', 'dns'],
        ['advanced', 'gears'],
        ['resources', 'box'],
        ['loopback', 'loop'],
      ],
    },
    {
      id: 'other',
      entries: [
        ['backup', 'drive'],
        ['diagnostics', 'doc'],
        ['developer', 'hammer'],
        ['about', 'info'],
      ],
    },
  ];

  let autostart = $state(false);

  $effect(() => {
    if (app.tool === 'application') invoke('autostart_enabled').then((enabled) => (autostart = enabled));
  });

  async function setAutostart(enabled) {
    const previous = autostart;
    autostart = enabled;
    if ((await act('autostart', 'set_autostart', { enabled })) === undefined) autostart = previous;
  }

  async function exportDiagnostics() {
    const path = await act('diagnostics', 'export_diagnostics');
    if (path) notify(t('tools.exported', { path }));
  }
</script>

{#if !app.tool}
  <Page title={t('page.tools')}>
    {#snippet actions()}
      <div class="group glass">
        <button
          type="button"
          title={t('tools.diagnostics')}
          aria-label={t('tools.diagnostics')}
          disabled={app.busy.diagnostics}
          onclick={exportDiagnostics}><Icon name="share" /></button
        >
      </div>
    {/snippet}

    {#each sections as section (section.id)}
      <section class="form-section">
        <h2 class="section-title">{t(`tools.${section.id}`)}</h2>
        <div class="form-group">
          {#each section.entries as [id, icon] (id)}
            {#if id === 'diagnostics'}
              <div class="form-row">
                <span class="row-icon"><Icon name={icon} /></span>
                <div class="grow">
                  <span>{t('tools.diagnostics')}</span>
                  <span class="sub">{t('tools.diagnosticsHint')}</span>
                </div>
                <button type="button" class="pill plain" disabled={app.busy.diagnostics} onclick={exportDiagnostics}
                  >{t('tools.export')}</button
                >
              </div>
            {:else}
              <button type="button" class="form-row link" onclick={() => (app.tool = id)}>
                <span class="row-icon"><Icon name={icon} /></span>
                <span class="grow">{t(`tools.${id}`)}</span>
                {#if id === 'about'}<span class="sub">{app.version}</span>{/if}
                <span class="chevron"><Icon name="chevron" /></span>
              </button>
            {/if}
          {/each}
        </div>
      </section>
    {/each}
  </Page>
{:else if app.tool === 'application'}
  <Page title={t('tools.application')} onback={() => (app.tool = null)}>
    <section class="form-section">
      <div class="form-group">
        <div class="form-row">
          <div class="grow">
            <span>{t('tools.autostart')}</span>
            <span class="sub">{t('tools.autostartHint')}</span>
          </div>
          <Switch label={t('tools.autostart')} checked={autostart} disabled={app.busy.autostart} onchange={setAutostart} />
        </div>
      </div>
    </section>
  </Page>
{:else if app.tool === 'about'}
  <Page title={t('tools.about')} onback={() => (app.tool = null)}>
    <section class="form-section">
      <div class="form-group">
        <div class="form-row">
          <span class="grow">{t('tools.version')}</span>
          <span class="sub selectable">{app.version}</span>
        </div>
      </div>
    </section>
  </Page>
{:else}
  <Page title={t(`tools.${app.tool}`)} onback={() => (app.tool = null)} fill>
    <EmptyState icon="hourglass" title={t(`tools.${app.tool}`)} detail={t('tools.comingSoon')} />
  </Page>
{/if}
