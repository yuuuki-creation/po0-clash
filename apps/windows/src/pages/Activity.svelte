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
  import { settings } from '../lib/settings.svelte.js';

  const tabs = $derived(settings.value.captureLogs ? ['requests', 'connections', 'logs'] : ['requests', 'connections']);
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

  $effect(() => {
    if (!tabs.includes(view.tab)) view.tab = 'requests';
  });

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
  const chain = (c) => c.chains.toReversed().join(' › ');
  const levelLabel = (level) => (level === 'all' ? t('activity.allLevels') : t(`level.${level}`));
</script>

<Page title={t('page.activity')} capped={false} scroll={false}>
  <div class="activity-head">
    <div class="tabs" role="tablist" aria-label={t('page.activity')} style:--n={tabs.length} style:--i={tabs.indexOf(view.tab)}>
      {#each tabs as id (id)}
        <button type="button" role="tab" aria-selected={view.tab === id} class:act={view.tab === id} onclick={() => (view.tab = id)}
          >{t(`activity.${id}`)}</button
        >
      {/each}
      <span class="tabs-ind"></span>
    </div>
    {#if view.tab === 'logs'}
      <Menu
        label={t('activity.level')}
        triggerClass="btn"
        value={view.level}
        options={levels.map((value) => ({ value, label: levelLabel(value) }))}
        onchange={(level) => (view.level = level)}
      />
    {/if}
    <label class="search">
      <Icon name="search" />
      <input bind:value={view.query} aria-label={t('activity.search')} placeholder={t('activity.search')} spellcheck="false" />
    </label>
    <button type="button" class="icon-btn" title={clearLabel} aria-label={clearLabel} disabled={!total || app.busy['activity:clear']} onclick={clear}
      ><Icon name={view.tab === 'connections' ? 'close' : 'trash'} /></button
    >
  </div>

  {#if !items.length}
    <EmptyState icon={{ requests: 'activity', connections: 'link', logs: 'doc' }[view.tab]} title={t(`activity.${view.tab}Empty`)} />
  {:else if view.tab === 'logs'}
    <section class="tbl">
      {#each items as entry, i (`${entry.at}:${i}`)}
        <div class="row t-log">
          <span class="val">{clock(entry.at)}</span>
          <span class="log-{entry.level}">{t(`level.${entry.level}`)}</span>
          <span class="message" title={entry.message}>{entry.message}</span>
        </div>
      {/each}
    </section>
  {:else}
    <section class="tbl">
      <div class="row t-conn thead">
        <span class="c-time">{t('activity.time')}</span>
        <span>{t('activity.host')}</span>
        <span class="c-process">{t('activity.process')}</span>
        <span class="c-rule">{t('activity.rule')}</span>
        <span>{t('activity.chain')}</span>
        <span>{t('activity.traffic')}</span>
        <span></span>
      </div>
      {#each items as c (c.id)}
        <div class="row t-conn">
          <span class="val c-time">{clock(c.start)}</span>
          <span class="clip selectable" title={c.destination}>{c.host || c.destination}</span>
          <span class="val clip c-process" title={c.process ?? ''}>{c.process ?? '—'}</span>
          <span class="val clip c-rule" title={rule(c)}>{rule(c)}</span>
          <span class="val clip" title={chain(c)}>{chain(c)}</span>
          <span class="val clip">↑ {formatBytes(c.upload)} ↓ {formatBytes(c.download)}</span>
          {#if view.tab === 'connections'}
            <button
              type="button"
              class="icon-btn"
              title={t('activity.close')}
              aria-label={t('activity.close')}
              disabled={app.busy[`close:${c.id}`]}
              onclick={() => close(c.id)}><Icon name="close" /></button
            >
          {:else}<span></span>{/if}
        </div>
      {/each}
    </section>
  {/if}
</Page>
