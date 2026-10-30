<script module>
  let tab = $state('requests');
</script>

<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app } from '../lib/core.svelte.js';
  import { formatBytes, formatTime, t } from '../lib/i18n.js';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import Page from '../lib/Page.svelte';

  const tabs = ['requests', 'connections', 'logs'];
  const loaders = {
    requests: async () => (requests = (await invoke('requests')).toReversed()),
    connections: async () => (connections = (await invoke('connections')).items.toSorted((a, b) => b.start - a.start)),
    logs: async () => (logs = (await invoke('logs')).toReversed()),
  };

  let requests = $state([]);
  let connections = $state([]);
  let logs = $state([]);

  const items = $derived({ requests, connections, logs }[tab]);
  const subtitle = $derived(
    t({ requests: 'activity.requestCount', connections: 'activity.connectionCount', logs: 'activity.logCount' }[tab], {
      count: items.length,
    }),
  );

  $effect(() => {
    const load = loaders[tab];
    const poll = () => !document.hidden && load().catch(() => {});
    poll();
    const timer = setInterval(poll, 1000);
    return () => clearInterval(timer);
  });

  async function clear() {
    if (tab === 'requests') await act('activity:clear', 'clear_requests');
    else if (tab === 'logs') await act('activity:clear', 'clear_logs');
    else await act('activity:clear', 'close_all_connections');
    await loaders[tab]();
  }

  async function close(id) {
    await act(`close:${id}`, 'close_connection', { id });
    await loaders.connections();
  }

  const clearLabel = $derived(
    { requests: t('activity.clearRequests'), connections: t('activity.closeAll'), logs: t('activity.clearLogs') }[tab],
  );
  const destination = (c) => c.host || c.destination;
  const route = (c) => [c.rulePayload ? `${c.rule} · ${c.rulePayload}` : c.rule, c.chains.toReversed().join(' → ')];
</script>

<Page title={t('page.activity')} {subtitle} fill={!items.length}>
  {#snippet actions()}
    <div class="group glass segments" role="radiogroup" aria-label={t('page.activity')}>
      {#each tabs as id (id)}
        <button type="button" role="radio" aria-checked={tab === id} class:selected={tab === id} onclick={() => (tab = id)}
          >{t(`activity.${id}`)}</button
        >
      {/each}
    </div>
    <div class="group glass">
      <button
        type="button"
        title={clearLabel}
        aria-label={clearLabel}
        disabled={!items.length || app.busy['activity:clear']}
        onclick={clear}><Icon name={tab === 'connections' ? 'close' : 'trash'} /></button
      >
    </div>
  {/snippet}

  {#if !items.length}
    <EmptyState
      icon={{ requests: 'activity', connections: 'network', logs: 'doc' }[tab]}
      title={t(`activity.${tab}Empty`)}
      detail={t(`activity.${tab}Hint`)}
    />
  {:else if tab === 'logs'}
    <div class="form-group">
      {#each logs as entry, i (`${entry.at}:${i}`)}
        <div class="form-row top log">
          <span class="tag level {entry.level}">{entry.level}</span>
          <span class="grow selectable">{entry.message}</span>
          <span class="sub mono">{formatTime(entry.at)}</span>
        </div>
      {/each}
    </div>
  {:else}
    <div class="form-group">
      {#each items as c (c.id)}
        {@const [rule, chain] = route(c)}
        <div class="form-row top">
          <span class="tag">{c.network}</span>
          <div class="grow">
            <span class="title selectable">{destination(c)}</span>
            <span class="sub title">{[c.process, rule, chain].filter(Boolean).join('  ·  ')}</span>
          </div>
          <div class="traffic sub mono">
            <span>↑ {formatBytes(c.upload)} ↓ {formatBytes(c.download)}</span>
            <span>{formatTime(c.start)}</span>
          </div>
          {#if tab === 'connections'}
            <button
              type="button"
              class="icon-button"
              title={t('activity.close')}
              aria-label={t('activity.close')}
              disabled={app.busy[`close:${c.id}`]}
              onclick={() => close(c.id)}><Icon name="close" /></button
            >
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</Page>
