<script>
  import { act, app, refreshExitIp } from '../lib/core.svelte.js';
  import { formatRate, t } from '../lib/i18n.js';
  import Icon from '../lib/Icon.svelte';
  import Segmented from '../lib/Segmented.svelte';

  const engine = $derived(app.status?.engine.state ?? 'stopped');
  const active = $derived(engine === 'running' || engine === 'starting');
  const profile = $derived(app.profiles.find((p) => p.selected));
  const exitIpText = $derived.by(() => {
    if (app.exitIpLoading && !app.exitIp) return '…';
    if (!app.exitIp) return '—';
    return app.exitIp.country ? `${app.exitIp.ip} · ${app.exitIp.country}` : app.exitIp.ip;
  });

  const modes = ['rule', 'global', 'direct'];
  const routes = ['tun', 'systemProxy'];
</script>

<section class="hero">
  <button
    type="button"
    class="power glass"
    class:on={active}
    disabled={app.busy.power || !app.status}
    aria-label={active ? t('home.disconnect') : t('home.connect')}
    onclick={() => act('power', active ? 'stop' : 'start')}
  >
    <Icon name="power" />
  </button>
  <div class="state {engine}">{t(`engine.${engine}`)}</div>
  {#if engine === 'failed'}
    <p class="error-text">{app.status.engine.message}</p>
    <button type="button" class="pill filled" disabled={app.busy.power} onclick={() => act('power', 'start')}
      >{t('home.reconnect')}</button
    >
  {:else if profile}
    <div class="sub">{profile.kind === 'links' ? t('profiles.links') : profile.name}</div>
  {/if}
</section>

<div class="section-title">{t('home.status')}</div>
<div class="group">
  <div class="row">
    <span class="grow">{t('home.node')}</span>
    <span class="value">{app.status?.currentNode ?? '—'}</span>
  </div>
  <button type="button" class="row" onclick={refreshExitIp}>
    <span class="grow">{t('home.exitIp')}</span>
    <span class="value">{exitIpText}</span>
  </button>
  <div class="row">
    <span class="grow">{t('home.upload')}</span>
    <span class="value mono">{formatRate(app.traffic.up)}</span>
  </div>
  <div class="row">
    <span class="grow">{t('home.download')}</span>
    <span class="value mono">{formatRate(app.traffic.down)}</span>
  </div>
</div>

<div class="control-label">{t('home.mode')}</div>
<Segmented
  label={t('home.mode')}
  options={modes.map((value) => ({ value, label: t(`mode.${value}`) }))}
  value={app.status?.mode}
  disabled={app.busy.mode || !app.status}
  onchange={(mode) => act('mode', 'set_mode', { mode })}
/>
<div class="control-label">{t('home.route')}</div>
<Segmented
  label={t('home.route')}
  options={routes.map((value) => ({ value, label: t(`route.${value}`) }))}
  value={app.status?.routeMode}
  disabled={app.busy.route || !app.status}
  onchange={(routeMode) => act('route', 'set_route_mode', { routeMode })}
/>
