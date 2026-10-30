<script>
  import { act, app } from './core.svelte.js';
  import { formatElapsed, t } from './i18n.js';
  import Icon from './Icon.svelte';

  const engine = $derived(app.status?.engine.state ?? 'stopped');
  const active = $derived(engine === 'running' || engine === 'starting');

  let now = $state(Date.now());
  $effect(() => {
    if (!app.connectedAt) return;
    now = Date.now();
    const timer = setInterval(() => (now = Date.now()), 1000);
    return () => clearInterval(timer);
  });
</script>

<button
  type="button"
  class="start"
  disabled={app.busy.power || !app.status}
  title={active ? t('home.disconnect') : t('home.connect')}
  aria-label={active ? t('home.disconnect') : t('home.connect')}
  onclick={() => act('power', active ? 'stop' : 'start')}
>
  {#if engine === 'starting' || app.busy.power}
    <span class="spinner"></span>
  {:else}
    <Icon name={active ? 'stop' : 'play'} />
  {/if}
  {#if app.connectedAt}
    <span>{formatElapsed(now - app.connectedAt)}</span>
  {:else}
    <span>{active ? t('home.connecting') : t('home.connect')}</span>
  {/if}
</button>
