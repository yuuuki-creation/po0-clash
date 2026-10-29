<script>
  import { act, app, refreshExitIp } from '../lib/core.svelte.js';
  import { formatRate, t } from '../lib/i18n.js';
  import Segmented from '../lib/Segmented.svelte';

  const engine = $derived(app.status?.engine.state ?? 'stopped');
  const active = $derived(engine === 'running' || engine === 'starting');
  const exitIpText = $derived.by(() => {
    if (app.exitIpLoading && !app.exitIp) return '…';
    if (!app.exitIp) return '—';
    return app.exitIp.country ? `${app.exitIp.ip} · ${app.exitIp.country}` : app.exitIp.ip;
  });

  const modes = ['rule', 'global', 'direct'];
  const routes = ['tun', 'systemProxy'];
</script>

<section class="card hero">
  <button
    type="button"
    class="power"
    class:on={active}
    class:pending={engine === 'starting'}
    disabled={app.busy.power || !app.status}
    aria-label={active ? t('home.disconnect') : t('home.connect')}
    onclick={() => act('power', active ? 'stop' : 'start')}
  >
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 3v8" />
      <path d="M6.3 6.8a8 8 0 1 0 11.4 0" />
    </svg>
  </button>
  <div class="hero-text">
    <div class="state {engine}">{t(`engine.${engine}`)}</div>
    {#if engine === 'failed'}
      <p class="error-text">{app.status.engine.message}</p>
      <button type="button" class="accent" disabled={app.busy.power} onclick={() => act('power', 'start')}
        >{t('home.reconnect')}</button
      >
    {:else}
      <div class="sub">{active ? t('home.disconnect') : t('home.connect')}</div>
    {/if}
  </div>
</section>

<section class="card list">
  <div class="row">
    <span class="sub">{t('home.node')}</span>
    <span class="value">{app.status?.currentNode ?? '—'}</span>
  </div>
  <div class="row">
    <span class="sub">{t('home.exitIp')}</span>
    <button type="button" class="plain value" class:loading={app.exitIpLoading} onclick={refreshExitIp}>{exitIpText}</button>
  </div>
  <div class="row">
    <span class="sub">{t('home.upload')}</span>
    <span class="value mono">{formatRate(app.traffic.up)}</span>
  </div>
  <div class="row">
    <span class="sub">{t('home.download')}</span>
    <span class="value mono">{formatRate(app.traffic.down)}</span>
  </div>
</section>

<section class="card stack">
  <div class="label">{t('home.mode')}</div>
  <Segmented
    label={t('home.mode')}
    options={modes.map((value) => ({ value, label: t(`mode.${value}`) }))}
    value={app.status?.mode}
    disabled={app.busy.mode || !app.status}
    onchange={(mode) => act('mode', 'set_mode', { mode })}
  />
  <div class="label">{t('home.route')}</div>
  <Segmented
    label={t('home.route')}
    options={routes.map((value) => ({ value, label: t(`route.${value}`) }))}
    value={app.status?.routeMode}
    disabled={app.busy.route || !app.status}
    onchange={(routeMode) => act('route', 'set_route_mode', { routeMode })}
  />
</section>
