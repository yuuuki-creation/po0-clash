<script>
  import { act, app, refreshAll, refreshExitIp } from '../lib/core.svelte.js';
  import { invoke } from '@tauri-apps/api/core';
  import { delayTone, formatBytes, formatDelay, formatElapsed, formatRate, t } from '../lib/i18n.js';
  import Card from '../lib/Card.svelte';
  import Icon from '../lib/Icon.svelte';
  import Page from '../lib/Page.svelte';
  import Segmented from '../lib/Segmented.svelte';
  import Sparkline from '../lib/Sparkline.svelte';
  import Switch from '../lib/Switch.svelte';
  import UsageBar from '../lib/UsageBar.svelte';

  const engine = $derived(app.status?.engine.state ?? 'stopped');
  const running = $derived(engine === 'running');
  const active = $derived(running || engine === 'starting');
  const profile = $derived(app.profiles.find((p) => p.selected));
  const node = $derived(running ? app.status?.currentNode : null);
  const nodeDelay = $derived(
    node ? app.groups.flatMap((g) => g.nodes).find((n) => n.name === node && n.delay != null)?.delay : null,
  );
  const entries = $derived(app.whitelist.entries);
  const applied = $derived(entries.filter((e) => e.result?.outcome === 'applied').length);
  const subtitle = $derived(
    running ? t('status.running', { route: t(`route.${app.status.routeMode}`) }) : t(`status.${engine}`),
  );

  let refreshing = $state(false);
  let now = $state(Date.now());
  $effect(() => {
    if (!app.connectedAt) return;
    now = Date.now();
    const timer = setInterval(() => (now = Date.now()), 1000);
    return () => clearInterval(timer);
  });

  let totals = $state(null);
  $effect(() => {
    if (!running) {
      totals = null;
      return;
    }
    const load = () => !document.hidden && invoke('connections').then((c) => (totals = c), () => {});
    load();
    const timer = setInterval(load, 2000);
    return () => clearInterval(timer);
  });

  async function refresh() {
    refreshing = true;
    await refreshAll();
    refreshing = false;
  }

  const profileTitle = (p) => (p.kind === 'links' ? t('profiles.links') : p.name);
</script>

<Page title={t('page.dashboard')} {subtitle}>
  {#snippet actions()}
    <div class="group glass">
      <button type="button" title={t('home.refresh')} aria-label={t('home.refresh')} disabled={refreshing} onclick={refresh}
        ><Icon name="refresh" /></button
      >
    </div>
  {/snippet}

  {#if engine === 'failed'}
    <div class="card failure">
      <span class="tone-bad"><Icon name="warning" /></span>
      <div class="grow">
        <span class="strong">{t('status.failed')}</span>
        <span class="sub selectable">{app.status.engine.message}</span>
      </div>
      <button type="button" class="pill plain" disabled={app.busy.power} onclick={() => act('power', 'start')}
        >{t('home.reconnect')}</button
      >
    </div>
  {/if}

  <div class="dashboard">
    <Card title={t('home.speed')} icon="gauge" wide>
      <div class="speed">
        <div class="rates">
          <span><Icon name="up" />{running ? formatRate(app.traffic.up) : '—'}</span>
          <span class="tone-accent"><Icon name="down" />{running ? formatRate(app.traffic.down) : '—'}</span>
        </div>
        <Sparkline history={app.history} />
      </div>
    </Card>

    <Card title={t('home.mode')} icon="branch">
      <Segmented
        label={t('home.mode')}
        options={['rule', 'global', 'direct'].map((value) => ({ value, label: t(`mode.${value}`) }))}
        value={app.status?.mode}
        disabled={app.busy.mode || !app.status}
        onchange={(mode) => act('mode', 'set_mode', { mode })}
      />
    </Card>

    <Card title={t('home.node')} icon="nodes">
      <button type="button" class="split link-row" onclick={() => (app.page = 'proxies')}>
        <span class="grow">
          <span class="big title">{node ?? '—'}</span>
          {#if nodeDelay != null}<span class="sub tone-{delayTone(nodeDelay)}">{formatDelay(nodeDelay)}</span>{/if}
        </span>
        <span class="chevron"><Icon name="chevron" /></span>
      </button>
    </Card>

    <Card title={t('home.route')} icon="route">
      <Segmented
        label={t('home.route')}
        options={['systemProxy', 'tun'].map((value) => ({ value, label: t(`route.${value}`) }))}
        value={app.status?.routeMode}
        disabled={app.busy.route || !app.status}
        onchange={(routeMode) => act('route', 'set_route_mode', { routeMode })}
      />
    </Card>

    <Card title={t('home.total')} icon="updown">
      <div class="rates">
        <span><Icon name="up" />{totals ? formatBytes(totals.uploadTotal) : '—'}</span>
        <span><Icon name="down" />{totals ? formatBytes(totals.downloadTotal) : '—'}</span>
      </div>
    </Card>

    <Card title={t('home.exitIp')} icon="network">
      <div class="split">
        <div class="grow">
          <span class="big selectable">{app.exitIp?.ip ?? (app.exitIpLoading ? '…' : '—')}</span>
          {#if app.exitIp?.country}<span class="sub">{app.exitIp.country}</span>{/if}
        </div>
        <button
          type="button"
          class="icon-button"
          title={t('home.refresh')}
          aria-label={t('home.refresh')}
          disabled={app.exitIpLoading}
          onclick={() => refreshExitIp()}><Icon name="refresh" /></button
        >
      </div>
    </Card>

    <Card title={t('home.profile')} icon="stack">
      {#if !app.profiles.length}
        <button type="button" class="text-button" onclick={() => (app.page = 'profiles')}>{t('home.addProfile')}</button>
      {:else}
        <select
          aria-label={t('home.profile')}
          value={profile?.id}
          disabled={Object.keys(app.busy).some((key) => key.startsWith('select:'))}
          onchange={(event) => act(`select:${event.target.value}`, 'select_profile', { id: event.target.value })}
        >
          {#each app.profiles as p (p.id)}
            <option value={p.id}>{profileTitle(p)}</option>
          {/each}
        </select>
        {#if profile?.usage}<UsageBar usage={profile.usage} />{/if}
      {/if}
    </Card>

    <Card title={t('home.connections')} icon="activity">
      <button type="button" class="split link-row" onclick={() => (app.page = 'activity')}>
        <span class="grow big mono">{totals ? totals.items.length : '—'}</span>
        <span class="chevron"><Icon name="chevron" /></span>
      </button>
    </Card>

    <Card title={t('home.memory')} icon="chip">
      <span class="big mono">{running && app.memory ? formatBytes(app.memory) : '—'}</span>
    </Card>

    <Card title={t('home.whitelist')} icon="shield">
      <div class="split">
        <button type="button" class="link-row sub" onclick={() => (app.page = 'whitelist')}>
          {entries.length ? t('home.whitelisted', { applied, total: entries.length }) : t('home.noEntries')}
        </button>
        <Switch
          label={t('home.whitelist')}
          checked={app.whitelist.enabled}
          disabled={app.busy['wl:enabled']}
          onchange={(enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })}
        />
      </div>
    </Card>
  </div>
</Page>

<button
  type="button"
  class="start glass"
  class:prominent={!active}
  disabled={app.busy.power || !app.status}
  title={active ? t('home.disconnect') : t('home.connect')}
  onclick={() => act('power', active ? 'stop' : 'start')}
>
  {#if engine === 'starting' || app.busy.power}
    <span class="spinner"></span>
  {:else}
    <Icon name={active ? 'stop' : 'play'} />
  {/if}
  {#if app.connectedAt}
    <span class="mono">{formatElapsed(now - app.connectedAt)}</span>
  {:else}
    <span>{active ? t('home.connecting') : t('home.connect')}</span>
  {/if}
</button>
