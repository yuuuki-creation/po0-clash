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
        ['providers', 'providers'],
        ['rules', 'rules'],
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
    await updateSettings({ language });
    location.reload();
  }

  const back = () => navigate('tools', null, 'back');

  // FlClash turns developer mode on after five clicks on the version.
  let versionClicks = 0;
  async function clickVersion() {
    if (++versionClicks !== 5 || s.developerMode) return;
    await updateSettings({ developerMode: true });
    notify(t('dev.enabled'));
  }
  const Sub = $derived(pages[app.tool]);
  const ready = $derived(!engineForms[app.tool] || engine.options);
</script>

{#if !app.tool}
  <Page title={t('page.tools')} form>
    {#snippet actions()}
      <div class="tb-group glass">
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
      <h2 class="group-title">{t(`tools.${section.id}`)}</h2>
      <div class="list">
        {#each section.entries.filter(([id]) => id !== 'developer' || s.developerMode) as [id, icon] (id)}
          {#if id === 'diagnostics'}
            <div class="row tall with-icon">
              <span class="row-icon"><Icon name={icon} /></span>
              <div class="label">
                <span>{t('tools.diagnostics')}</span>
                <span class="sub">{t('tools.diagnosticsHint')}</span>
              </div>
              <button type="button" class="pill" disabled={app.busy.diagnostics} onclick={exportDiagnostics}
                >{t('tools.export')}</button
              >
            </div>
          {:else}
            <button type="button" class="row with-icon" onclick={() => navigate('tools', id, 'forward')}>
              <span class="row-icon"><Icon name={icon} /></span>
              <span class="label">{t(`tools.${id}`)}</span>
              <span class="trailing">
                {#if id === 'about'}{app.version}{:else if id === 'language'}{languageLabel}{/if}
                <span class="chevron"><Icon name="chevron" /></span>
              </span>
            </button>
          {/if}
        {/each}
      </div>
    {/each}
  </Page>
{:else if app.tool === 'application'}
  <Page title={t('tools.application')} subtitle={t('page.tools')} onback={back} form>
    <h2 class="group-title">{t('app.launch')}</h2>
    <div class="list">
      <div class="row tall">
        <div class="label"><span>{t('tools.autostart')}</span><span class="sub">{t('tools.autostartHint')}</span></div>
        <Switch label={t('tools.autostart')} checked={autostart} disabled={app.busy.autostart} onchange={setAutostart} />
      </div>
      {#each [['silentLaunch', true], ['autoConnect', true], ['minimizeOnClose', true]] as [key, hint] (key)}
        <Toggle label={t(`app.${key}`)} hint={hint ? t(`app.${key}Hint`) : ''} checked={s[key]} onchange={set(key)} />
      {/each}
    </div>
    <h2 class="group-title">{t('app.interface')}</h2>
    <div class="list">
      <Toggle label={t('app.pageAnimation')} checked={s.pageAnimation} onchange={set('pageAnimation')} />
      <Toggle label={t('app.showNavLabels')} checked={s.showNavLabels} onchange={set('showNavLabels')} />
      <Toggle label={t('app.captureLogs')} hint={t('app.captureLogsHint')} checked={s.captureLogs} onchange={set('captureLogs')} />
    </div>
    <h2 class="group-title">{t('app.network')}</h2>
    <div class="list">
      <Toggle
        label={t('app.closeOnSwitch')}
        hint={t('app.closeOnSwitchHint')}
        checked={s.closeConnectionsOnSwitch}
        onchange={set('closeConnectionsOnSwitch')}
      />
      <Toggle label={t('app.checkCertificate')} checked={s.checkCertificate} onchange={set('checkCertificate')} />
    </div>
  </Page>
{:else if app.tool === 'language'}
  <Page title={t('tools.language')} subtitle={t('page.tools')} onback={back} form>
    <div class="list">
      {#each languages as [value, name] (value)}
        <button type="button" class="row" onclick={() => setLanguage(value)}>
          <span class="label">{name}</span>
          {#if s.language === value}<span class="row-icon"><Icon name="check" /></span>{/if}
        </button>
      {/each}
    </div>
    <p class="note">{t('lang.hint')}</p>
  </Page>
{:else if app.tool === 'about'}
  <Page title={t('tools.about')} subtitle={t('page.tools')} onback={back} form>
    <div class="list">
      <button type="button" class="row" onclick={clickVersion}>
        <span class="label">{t('tools.version')}</span>
        <span class="trailing">{app.version}</span>
      </button>
      <button type="button" class="row" onclick={() => navigate('tools', 'licenses', 'forward')}>
        <span class="label">{t('licenses.title')}</span>
        <span class="chevron"><Icon name="chevron" /></span>
      </button>
    </div>
  </Page>
{:else if app.tool === 'licenses'}
  <Licenses onback={() => navigate('tools', 'about', 'back')} />
{:else if app.tool === 'loopback'}
  <Loopback onback={back} />
{:else if app.tool === 'rules'}
  <Page title={t('tools.rules')} subtitle={t('page.tools')} onback={back} form>
    {#snippet actions()}
      <label class="search glass">
        <Icon name="search" />
        <input bind:value={ruleQuery} aria-label={t('rules.search')} placeholder={t('rules.search')} spellcheck="false" />
      </label>
    {/snippet}
    <Rules query={ruleQuery} />
  </Page>
{:else if Sub}
  <Page title={t(`tools.${app.tool}`)} subtitle={t('page.tools')} onback={back} form>
    {#snippet actions()}
      {#if app.tool === 'dns'}
        <div class="tb-group glass">
          <button type="button" disabled={app.busy.flush || app.status?.engine.state !== 'running'} onclick={flushDns}
            >{t('opt.flushDns')}</button
          >
        </div>
      {/if}
    {/snippet}
    {#if ready}<Sub />{/if}
  </Page>
{/if}
