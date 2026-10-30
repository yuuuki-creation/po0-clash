<script module>
  const view = $state({ tab: 'requests', query: '', level: 'all' });
</script>

<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app } from '../lib/core.svelte.js';
  import { formatBytes, t } from '../lib/i18n.js';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import Menu from '../lib/Menu.svelte';
  import Page from '../lib/Page.svelte';

  const tabs = ['requests', 'connections', 'logs'];
  const levels = ['all', 'debug', 'info', 'warning', 'error'];
  let requests = $state([]);
  let connections = $state([]);
  let logs = $state([]);

  const loaders = {
    requests: async () => (requests = (await invoke('requests')).toReversed()),
    connections: async () => (connections = (await invoke('connections')).items.toSorted((a, b) => b.start - a.start)),
    logs: async () => (logs = (await invoke('logs')).toReversed()),
  };

  const query = $derived(view.query.trim().toLowerCase());
  const matches = (c) =>
    !query ||
    [c.host, c.destination, c.process, c.rule, c.rulePayload, ...c.chains].some((v) => v?.toLowerCase().includes(query));
  const items = $derived.by(() => {
    if (view.tab === 'logs') {
      return logs.filter(
        (l) => (view.level === 'all' || l.level === view.level) && (!query || l.message.toLowerCase().includes(query)),
      );
    }
    return (view.tab === 'requests' ? requests : connections).filter(matches);
  });
  const total = $derived({ requests, connections, logs }[view.tab].length);
  const subtitle = $derived(
    t({ requests: 'activity.requestCount', connections: 'activity.connectionCount', logs: 'activity.logCount' }[view.tab], {
      count: total,
    }),
  );

  $effect(() => {
    const load = loaders[view.tab];
    const poll = () => !document.hidden && load().catch(() => {});
    poll();
    const timer = setInterval(poll, 1000);
    return () => clearInterval(timer);
  });

  async function clear() {
    const command = { requests: 'clear_requests', connections: 'close_all_connections', logs: 'clear_logs' }[view.tab];
    await act('activity:clear', command);
    await loaders[view.tab]();
  }

  async function close(id) {
    await act(`close:${id}`, 'close_connection', { id });
    await loaders.connections();
  }

  const clearLabel = $derived(
    { requests: t('activity.clearRequests'), connections: t('activity.closeAll'), logs: t('activity.clearLogs') }[view.tab],
  );
  const clock = (unix) => new Date(unix * 1000).toLocaleTimeString([], { hour12: false });
  const rule = (c) => (c.rulePayload ? `${c.rule}(${c.rulePayload})` : c.rule);
</script>

<Page title={t('page.activity')} {subtitle} fill={!items.length}>
  {#snippet actions()}
    <label class="search glass">
      <Icon name="search" />
      <input bind:value={view.query} aria-label={t('activity.search')} placeholder={t('activity.search')} spellcheck="false" />
    </label>
    {#if view.tab === 'logs'}
      <div class="tb-group glass">
        <Menu
          label={t('activity.level')}
          value={view.level}
          options={levels.map((value) => ({ value, label: value === 'all' ? t('activity.allLevels') : t(`level.${value}`) }))}
          onchange={(level) => (view.level = level)}
        >
          {#snippet trigger()}<span class="trigger-label"
              >{view.level === 'all' ? t('activity.allLevels') : t(`level.${view.level}`)}<Icon name="updown-chevron" /></span
            >{/snippet}
        </Menu>
      </div>
    {/if}
    <div class="tb-group glass" role="radiogroup" aria-label={t('page.activity')}>
      {#each tabs as id (id)}
        <button type="button" role="radio" aria-checked={view.tab === id} class:on={view.tab === id} onclick={() => (view.tab = id)}
          >{t(`activity.${id}`)}</button
        >
      {/each}
    </div>
    <div class="tb-group glass">
      <button type="button" title={clearLabel} aria-label={clearLabel} disabled={!total || app.busy['activity:clear']} onclick={clear}
        ><Icon name={view.tab === 'connections' ? 'close' : 'trash'} /></button
      >
    </div>
  {/snippet}

  {#if !items.length}
    <EmptyState
      icon={{ requests: 'activity', connections: 'link', logs: 'doc' }[view.tab]}
      title={t(`activity.${view.tab}Empty`)}
      detail={t(`activity.${view.tab}Hint`)}
    />
  {:else if view.tab === 'logs'}
    <div class="table logs">
      <div class="table-row table-head">
        <span>{t('activity.time')}</span><span>{t('activity.level')}</span><span>{t('activity.message')}</span>
      </div>
      {#each items as entry, i (`${entry.at}:${i}`)}
        <div class="table-row">
          <span class="sub mono">{clock(entry.at)}</span>
          <span class="level {entry.level}">{t(`level.${entry.level}`)}</span>
          <span class="message selectable">{entry.message}</span>
        </div>
      {/each}
    </div>
  {:else}
    <div class="table">
      <div class="table-row table-head">
        <span>{t('activity.time')}</span><span>{t('activity.host')}</span><span>{t('activity.process')}</span><span
          >{t('activity.rule')}</span
        ><span>{t('activity.chain')}</span><span class="traffic">{t('activity.traffic')}</span><span></span>
      </div>
      {#each items as c (c.id)}
        <div class="table-row">
          <span class="sub mono">{clock(c.start)}</span>
          <span class="host selectable" title={c.destination}>{c.host || c.destination}</span>
          <span class="sub">{c.process ?? '—'}</span>
          <span class="sub" title={rule(c)}>{rule(c)}</span>
          <span class="sub" title={c.chains.toReversed().join(' → ')}>{c.chains.toReversed().join(' → ')}</span>
          <span class="sub mono traffic">↑ {formatBytes(c.upload)} ↓ {formatBytes(c.download)}</span>
          {#if view.tab === 'connections'}
            <button
              type="button"
              class="icon-button"
              title={t('activity.close')}
              aria-label={t('activity.close')}
              disabled={app.busy[`close:${c.id}`]}
              onclick={() => close(c.id)}><Icon name="close" /></button
            >
          {:else}<span></span>{/if}
        </div>
      {/each}
    </div>
  {/if}
</Page>
