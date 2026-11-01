<script module>
  let ruleQuery = $state('');
</script>

<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../lib/core.svelte.js';
  import { engine, loadOptions } from '../lib/engine.svelte.js';
  import { t } from '../lib/i18n.js';
  import Icon from '../lib/Icon.svelte';
  import { navigate } from '../lib/motion.svelte.js';
  import Page from '../lib/Page.svelte';
  import Segmented from '../lib/Segmented.svelte';
  import Switch from '../lib/Switch.svelte';
  import Toggle from '../lib/form/Toggle.svelte';
  import { settings, updateSettings } from '../lib/settings.svelte.js';
  import Advanced from './tools/Advanced.svelte';
  import Appearance from './tools/Appearance.svelte';
  import Backup from './tools/Backup.svelte';
  import Basic from './tools/Basic.svelte';
  import Developer from './tools/Developer.svelte';
  import Dns from './tools/Dns.svelte';
  import Hotkeys from './tools/Hotkeys.svelte';
  import Licenses from './tools/Licenses.svelte';
  import Loopback from './tools/Loopback.svelte';
  import Network from './tools/Network.svelte';
  import Providers from './tools/Providers.svelte';
  import Resources from './tools/Resources.svelte';
  import Rules from './tools/Rules.svelte';

  const columns = [
    [
      { id: 'settings', entries: ['language', 'appearance', 'application', 'hotkeys'] },
      { id: 'other', entries: ['backup', 'diagnostics', 'developer', 'about'] },
    ],
    [{ id: 'network', entries: ['basic', 'networkSettings', 'dns', 'advanced', 'resources', 'providers', 'rules', 'loopback'] }],
  ];
  const engineForms = { basic: Basic, networkSettings: Network, dns: Dns, advanced: Advanced, resources: Resources };
  const pages = {
    appearance: Appearance,
    providers: Providers,
    backup: Backup,
    hotkeys: Hotkeys,
    developer: Developer,
    ...engineForms,
  };

  let autostart = $state(false);

  $effect(() => {
    if (app.tool === 'application') invoke('autostart_enabled').then((enabled) => (autostart = enabled));
    if (engineForms[app.tool]) loadOptions().catch((e) => notify(e));
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

  async function flushDns() {
    if ((await act('flush', 'flush_dns_cache')) !== undefined) notify(t('opt.flushed'));
  }

  const s = $derived(settings.value);
  const set = (key) => (value) => updateSettings({ [key]: value });
  const languages = [
    [null, t('lang.system')],
    ['zh_CN', '简体中文'],
    ['en', 'English'],
    ['ja', '日本語'],
    ['ru', 'Русский'],
  ];
  const languageLabel = $derived(languages.find(([value]) => value === s.language)?.[1] ?? t('lang.system'));

  async function setLanguage(language) {
    if (language === s.language) return;
    if (!(await updateSettings({ language }))) return;
    location.reload();
  }

  const back = () => navigate('tools', null, 'back');
  const root = () => [{ label: t('page.tools'), onclick: back }];

  // FlClash turns developer mode on after five clicks on the version.
  let versionClicks = 0;
  async function clickVersion() {
    if (++versionClicks !== 5 || s.developerMode) return;
    if (!(await updateSettings({ developerMode: true }))) {
      versionClicks = 0;
      return;
    }
    notify(t('dev.enabled'));
  }
  const Sub = $derived(pages[app.tool]);
  const ready = $derived(!engineForms[app.tool] || engine.options);
</script>

{#if !app.tool}
  <Page title={t('page.tools')}>
    <div class="cols">
      {#each columns as column, c (c)}
        <div class="col">
          {#each column as section (section.id)}
            <section>
              <h2 class="section-title">{t(`tools.${section.id}`)}</h2>
              <div class="group">
                {#each section.entries.filter((id) => id !== 'developer' || s.developerMode) as id (id)}
                  {#if id === 'diagnostics'}
                    <div class="row">
                      <span class="grow clip">{t('tools.diagnostics')}</span>
                      <button type="button" class="btn" disabled={app.busy.diagnostics} onclick={exportDiagnostics}>{t('tools.export')}</button>
                    </div>
                  {:else if id === 'appearance'}
                    <div class="row">
                      <button type="button" class="row-hit" aria-label={t('tools.appearance')} onclick={() => navigate('tools', id, 'drill')}></button>
                      <span class="grow clip">{t('tools.appearance')}</span>
                      <Segmented
                        label={t('ap.mode')}
                        value={s.themeMode}
                        options={['light', 'dark', 'system'].map((value) => ({ value, label: t(`ap.${value}`) }))}
                        onchange={(themeMode) => updateSettings({ themeMode })}
                      />
                      <Icon name="chevron" class="chev" />
                    </div>
                  {:else}
                    <button type="button" class="row" onclick={() => navigate('tools', id, 'drill')}>
                      <span class="grow clip">{t(`tools.${id}`)}</span>
                      {#if id === 'about'}<span class="val">{app.version}</span>{:else if id === 'language'}<span class="val">{languageLabel}</span>{/if}
                      <Icon name="chevron" class="chev" />
                    </button>
                  {/if}
                {/each}
              </div>
            </section>
          {/each}
        </div>
      {/each}
    </div>
  </Page>
{:else if app.tool === 'application'}
  <Page title={t('tools.application')} crumbs={root()}>
    <section>
      <h2 class="section-title">{t('app.launch')}</h2>
      <div class="group">
        <div class="row">
          <span class="grow">{t('tools.autostart')}</span>
          <Switch label={t('tools.autostart')} checked={autostart} disabled={app.busy.autostart} onchange={setAutostart} />
        </div>
        {#each ['silentLaunch', 'autoConnect', 'minimizeOnClose'] as key (key)}
          <Toggle label={t(`app.${key}`)} checked={s[key]} onchange={set(key)} />
        {/each}
      </div>
    </section>
    <section>
      <h2 class="section-title">{t('app.interface')}</h2>
      <div class="group">
        <Toggle label={t('app.pageAnimation')} checked={s.pageAnimation} onchange={set('pageAnimation')} />
        <Toggle label={t('app.showNavLabels')} checked={s.showNavLabels} onchange={set('showNavLabels')} />
        <Toggle label={t('app.captureLogs')} checked={s.captureLogs} onchange={set('captureLogs')} />
      </div>
    </section>
    <section>
      <h2 class="section-title">{t('app.network')}</h2>
      <div class="group">
        <Toggle label={t('app.closeOnSwitch')} checked={s.closeConnectionsOnSwitch} onchange={set('closeConnectionsOnSwitch')} />
        <Toggle label={t('app.checkCertificate')} checked={s.checkCertificate} onchange={set('checkCertificate')} />
      </div>
    </section>
  </Page>
{:else if app.tool === 'language'}
  <Page title={t('tools.language')} crumbs={root()}>
    <div class="group">
      {#each languages as [value, name] (value)}
        <button type="button" class="row" aria-pressed={s.language === value} onclick={() => setLanguage(value)}>
          <span class="grow">{name}</span>
          {#if s.language === value}<Icon name="check" />{/if}
        </button>
      {/each}
    </div>
  </Page>
{:else if app.tool === 'about'}
  <Page title={t('tools.about')} crumbs={root()}>
    <div class="group">
      <button type="button" class="row" onclick={clickVersion}>
        <span class="grow">{t('tools.version')}</span>
        <span class="val">{app.version}</span>
      </button>
      <button type="button" class="row" onclick={() => navigate('tools', 'licenses', 'drill')}>
        <span class="grow">{t('licenses.title')}</span>
        <Icon name="chevron" class="chev" />
      </button>
    </div>
  </Page>
{:else if app.tool === 'licenses'}
  <Licenses crumbs={[...root(), { label: t('tools.about'), onclick: () => navigate('tools', 'about', 'back') }]} />
{:else if app.tool === 'loopback'}
  <Loopback crumbs={root()} />
{:else if app.tool === 'rules'}
  <Page title={t('tools.rules')} crumbs={root()}>
    {#snippet actions()}
      <label class="search">
        <Icon name="search" />
        <input bind:value={ruleQuery} aria-label={t('rules.search')} placeholder={t('rules.search')} spellcheck="false" />
      </label>
    {/snippet}
    <Rules query={ruleQuery} />
  </Page>
{:else if Sub}
  <Page title={t(`tools.${app.tool}`)} crumbs={root()}>
    {#snippet actions()}
      {#if app.tool === 'dns'}
        <button type="button" class="btn" disabled={app.busy.flush || app.status?.engine.state !== 'running'} onclick={flushDns}
          >{t('opt.flushDns')}</button
        >
      {/if}
    {/snippet}
    {#if ready}<Sub />{/if}
  </Page>
{/if}
