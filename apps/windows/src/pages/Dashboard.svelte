<script module>
  let chosenGroup = $state(null);
</script>

<script>
  import { act, app, rankDelay, refreshExitIp, resolvedDelay, testDelay } from '../lib/core.svelte.js';
  import { displayOrder, moveCard } from '../lib/dashboard-cards.js';
  import { formatAgo, formatBytes, formatDate, formatDelay, formatElapsed, formatRate, formatUsage, t } from '../lib/i18n.js';
  import Card from '../lib/Card.svelte';
  import DelayButton from '../lib/DelayButton.svelte';
  import Icon from '../lib/Icon.svelte';
  import { navigate, rowIn, rowOut } from '../lib/motion.svelte.js';
  import Page from '../lib/Page.svelte';
  import SectionMenu from '../lib/SectionMenu.svelte';
  import Segmented from '../lib/Segmented.svelte';
  import { settings, updateSettings } from '../lib/settings.svelte.js';
  import SpeedChart from '../lib/SpeedChart.svelte';
  import Switch from '../lib/Switch.svelte';
  import Value from '../lib/Value.svelte';
  import { focusGroup } from './Proxies.svelte';

  const engine = $derived(app.status?.engine.state ?? 'stopped');
  const running = $derived(engine === 'running');
  const connecting = $derived(engine === 'starting' || (!running && !!app.busy.power));
  const statusTone = $derived({ running: 'on', starting: 'wait', failed: 'bad' }[engine] ?? '');

  let now = $state(Date.now());
  $effect(() => {
    if (!app.connectedAt) return;
    now = Date.now();
    const timer = setInterval(() => (now = Date.now()), 1000);
    return () => clearInterval(timer);
  });

  const powerLabels = $derived([
    { id: 'connect', text: t('home.connect') },
    { id: 'disconnect', text: t('home.disconnect') },
    { id: 'reconnect', text: t('home.reconnect') },
    { id: 'connecting', text: t('home.connecting'), spinner: true },
  ]);
  const powerState = $derived(connecting ? 'connecting' : running ? 'disconnect' : engine === 'failed' ? 'reconnect' : 'connect');

  const selectable = $derived(app.groups.filter((g) => g.selectable));
  const group = $derived(
    selectable.find((g) => g.name === chosenGroup) ??
      selectable.find((g) => g.now === app.status?.currentNode) ??
      selectable[0],
  );
  const node = $derived(running && group ? group.nodes.find((n) => n.name === group.now) : null);
  const alternatives = $derived.by(() => {
    if (!group) return [];
    const currentName = node?.name ?? group.now;
    return group.nodes
      .filter((n) => n.name !== currentName)
      .toSorted((a, b) => rankDelay(resolvedDelay(a)) - rankDelay(resolvedDelay(b)))
      .slice(0, 3);
  });
  const nodeSections = $derived.by(() => {
    if (!node) return [];
    const nodes = {
      title: t('home.switchTo'),
      value: node.name,
      close: true,
      options: group.nodes
        .toSorted((a, b) => rankDelay(resolvedDelay(a)) - rankDelay(resolvedDelay(b)))
        .map((n) => ({ value: n.name, label: n.name, detail: formatDelay(resolvedDelay(n)) })),
      onchange: (name) => act(`select:${group.name}`, 'select_node', { group: group.name, node: name }),
    };
    if (selectable.length < 2) return [nodes];
    const groups = {
      title: t('home.group'),
      value: group.name,
      options: selectable.map((g) => ({ value: g.name, label: g.name })),
      onchange: (name) => (chosenGroup = name),
    };
    return [nodes, groups];
  });

  const profile = $derived(app.profiles.find((p) => p.selected));
  const usage = $derived(profile?.usage);
  const used = $derived(usage ? usage.upload + usage.download : 0);
  const percent = $derived(usage?.total ? Math.min(100, Math.round((used / usage.total) * 100)) : null);
  const profileTitle = (p) => (p.kind === 'links' ? t('profiles.links') : p.name);
  const profileTip = $derived(
    [
      profile?.updatedAt && t('home.updated', { ago: formatAgo(profile.updatedAt) }),
      usage?.expire && t('profiles.expire', { date: formatDate(usage.expire) }),
    ]
      .filter(Boolean)
      .join(' · '),
  );

  const entries = $derived(app.whitelist.entries);
  const failing = $derived(entries.filter((e) => e.result && e.result.outcome !== 'applied').length);
  const applied = $derived(entries.filter((e) => e.result?.outcome === 'applied').length);
  const lastCheck = $derived(Math.max(0, ...entries.map((e) => e.result?.at ?? 0)));
  const whitelistStatus = $derived.by(() => {
    if (!app.whitelist.enabled) return { tone: '', text: t('home.whitelistOff') };
    if (!entries.length) return { tone: '', text: t('home.noEntries') };
    if (!lastCheck) return { tone: '', text: t('home.pending') };
    if (failing) return { tone: 'fair', text: t('home.issues', { count: failing }) };
    return { tone: 'good', text: t('whitelist.summary', { applied, total: entries.length }) };
  });

  const totals = $derived(app.totals);

  const titles = {
    currentNode: 'home.node',
    speed: 'home.speed',
    mode: 'home.mode',
    takeover: 'home.route',
    whitelist: 'home.whitelist',
    traffic: 'home.traffic',
    connections: 'home.connections',
    memory: 'home.memory',
    intranetIp: 'home.lan',
    subscription: 'home.profile',
    exitIp: 'home.exitIp',
  };
  const wide = new Set(['currentNode', 'speed', 'subscription', 'mode', 'traffic']);
  const rows = {
    currentNode,
    speed,
    mode,
    takeover,
    whitelist,
    traffic,
    connections,
    memory,
    intranetIp,
    subscription,
    exitIp,
  };
  const cards = $derived(displayOrder(settings.value.dashboardCards.filter((id) => rows[id])));
  const hidden = $derived(Object.keys(titles).filter((id) => !cards.includes(id)));

  let editing = $state(false);
  let dragged = $state(null);
  let target = $state(null);

  const saveCards = (dashboardCards) => updateSettings({ dashboardCards });

  function drop(over) {
    const from = dragged;
    dragged = target = null;
    if (!from || from === over) return;
    saveCards(moveCard(cards, from, over));
  }

  function moveWithKeyboard(event, id) {
    const direction = { ArrowUp: -1, ArrowDown: 1 }[event.key];
    if (!direction) return;
    event.preventDefault();
    const over = cards[cards.indexOf(id) + direction];
    if (over) saveCards(moveCard(cards, id, over));
  }

  function openGroup(name) {
    focusGroup(name);
    navigate('proxies');
  }

  const testBusy = $derived(!group || app.busy[`delay:${group.name}`] || group.nodes.some((n) => app.busy[`node:${n.name}`]));
</script>

<Page title={t('page.dashboard')}>
  {#snippet actions()}
    {#if !editing}
      <button
        type="button"
        class="icon-btn"
        title={t('home.test')}
        aria-label={t('home.test')}
        disabled={testBusy}
        onclick={() => testDelay(group.name)}
      >
        {#if group && app.busy[`delay:${group.name}`]}<span class="ring"></span>{:else}<Icon name="bolt" />{/if}
      </button>
    {/if}
    <button
      type="button"
      class={editing ? 'btn primary' : 'icon-btn'}
      title={editing ? t('home.done') : t('home.edit')}
      aria-label={editing ? t('home.done') : t('home.edit')}
      aria-pressed={editing}
      onclick={() => (editing = !editing)}>{#if editing}{t('home.done')}{:else}<Icon name="edit" />{/if}</button
    >
  {/snippet}

  <section class="hero-banner {statusTone}">
    <div class="hero-badge {statusTone}">
      <Icon name={running ? 'whitelist' : connecting ? 'bolt' : engine === 'failed' ? 'warning' : 'proxies'} />
    </div>
    <div class="grow status-text">
      <div class="status-main">
        <strong>{t(`status.${engine}`)}</strong>
        {#if app.connectedAt}<span class="hero-timer">{formatElapsed(now - app.connectedAt)}</span>{/if}
      </div>
      {#if engine === 'failed'}
        <span class="bad-text selectable">{app.status.engine.message}</span>
      {:else}
        <span class="hero-sub clip">
          {[profile && profileTitle(profile), group?.now, app.status?.routeMode && t(`route.${app.status.routeMode}`)].filter(Boolean).join(' · ') || t('home.addProfile')}
        </span>
      {/if}
    </div>
    <button
      type="button"
      class="btn power"
      class:primary={!running && !connecting}
      disabled={connecting || app.busy.power || !app.status}
      aria-label={powerLabels.find((label) => label.id === powerState).text}
      onclick={() => act('power', running ? 'stop' : 'start')}
    >
      <span class="power-labels">
        {#each powerLabels as label (label.id)}
          <span class:on={label.id === powerState}>
            {#if label.spinner}<span class="ring"></span>{/if}{label.text}
          </span>
        {/each}
      </span>
    </button>
  </section>

  {#if editing}
    <section class="group" role="list">
      {#each cards as id (id)}
        <div
          class="row edit-row"
          class:dragging={dragged === id}
          class:drop-target={target === id && dragged !== id}
          role="listitem"
          ondragover={(event) => {
            if (!dragged) return;
            event.preventDefault();
            event.dataTransfer.dropEffect = 'move';
            target = id;
          }}
          ondrop={(event) => {
            event.preventDefault();
            drop(id);
          }}
          in:rowIn
          out:rowOut
        >
          <button
            type="button"
            class="edit-grip"
            draggable="true"
            title={t('home.reorderCard', { name: t(titles[id]) })}
            aria-label={t('home.reorderCard', { name: t(titles[id]) })}
            onkeydown={(event) => moveWithKeyboard(event, id)}
            ondragstart={(event) => {
              dragged = id;
              event.dataTransfer.setData('text/plain', id);
              event.dataTransfer.effectAllowed = 'move';
            }}
            ondragend={() => (dragged = target = null)}><Icon name="grip" /></button
          >
          <span class="grow">{t(titles[id])}</span>
          <button
            type="button"
            class="icon-btn"
            title={t('home.removeCard')}
            aria-label={`${t('home.removeCard')} · ${t(titles[id])}`}
            onclick={() => saveCards(cards.filter((c) => c !== id))}><Icon name="close" /></button
          >
        </div>
      {/each}
    </section>
    {#if hidden.length}
      <section>
        <h2 class="section-title">{t('home.addCards')}</h2>
        <div class="group">
          {#each hidden as id (id)}
            <button type="button" class="row" onclick={() => saveCards([...cards, id])} in:rowIn out:rowOut>
              <span class="grow">{t(titles[id])}</span>
              <Icon name="plus" class="chev" />
            </button>
          {/each}
        </div>
      </section>
    {/if}
  {:else}
    <div class="bento-grid">
      {#each cards as id (id)}
        {@render rows[id]()}
      {/each}
    </div>
  {/if}
</Page>

{#snippet currentNode()}
  <Card title={t('home.node')} icon="proxies" span={wide.has('currentNode')}>
    {#snippet accessory()}
      {#if group}
        <button type="button" class="card-pill" onclick={() => openGroup(group.name)}>
          <span class="clip">{group.name}</span><Icon name="chevron" />
        </button>
      {/if}
    {/snippet}
    <div class="node-hero">
      <div class="node-main">
        {#if node}
          <SectionMenu label={t('home.switchTo')} sections={nodeSections} triggerClass="node-title-btn">
            {#snippet trigger()}<span class="clip">{node.name}</span><Icon name="chevDown" class="chev-d" />{/snippet}
          </SectionMenu>
        {:else}
          <button type="button" class="node-title-btn" onclick={() => openGroup(group?.name)}>
            <span class="clip">{group?.now ?? '—'}</span>
          </button>
        {/if}
        {#if node}
          <DelayButton {node} />
        {/if}
      </div>
      <span class="card-sub clip">{[node?.kind ?? group?.kind, group && `${group.nodes.length}`].filter(Boolean).join(' · ') || '—'}</span>
    </div>
    {#if group && alternatives.length}
      <div class="quick-nodes">
        {#each alternatives as alt (alt.name)}
          <button
            type="button"
            class="quick-chip"
            disabled={!group.selectable || app.busy[`select:${group.name}`]}
            onclick={() => act(`select:${group.name}`, 'select_node', { group: group.name, node: alt.name })}
          >
            <span class="clip">{alt.name}</span>
            {#if resolvedDelay(alt) != null}<span class="chip-delay">{formatDelay(resolvedDelay(alt))}</span>{/if}
          </button>
        {/each}
      </div>
    {/if}
  </Card>
{/snippet}

{#snippet speed()}
  <Card title={t('home.speed')} icon="chart" span={wide.has('speed')}>
    <div class="speed-metrics">
      <div class="speed-col">
        <Value text={formatRate(app.traffic.down)} size="large" />
        <span class="rate-legend dn"><span class="legend-dot dn"></span>↓</span>
      </div>
      <div class="speed-col">
        <Value text={formatRate(app.traffic.up)} size="large" />
        <span class="rate-legend up"><span class="legend-dot up"></span>↑</span>
      </div>
    </div>
    <SpeedChart history={app.history} />
  </Card>
{/snippet}

{#snippet mode()}
  <Card title={t('home.mode')} icon="branch" span={wide.has('mode')}>
    <Segmented
      label={t('home.mode')}
      options={['rule', 'global', 'direct'].map((value) => ({ value, label: t(`mode.${value}`) }))}
      value={app.status?.mode}
      disabled={app.busy.mode || !app.status}
      onchange={(mode) => act('mode', 'set_mode', { mode })}
    />
    <span class="card-sub">{t(`mode.${app.status?.mode ?? 'rule'}`)}</span>
  </Card>
{/snippet}

{#snippet takeover()}
  <Card title={t('home.route')} icon="wifi" span={wide.has('takeover')}>
    <Segmented
      label={t('home.route')}
      options={['tun', 'systemProxy'].map((value) => ({ value, label: t(`route.${value}`) }))}
      value={app.status?.routeMode}
      disabled={app.busy.route || !app.status}
      onchange={(routeMode) => act('route', 'set_route_mode', { routeMode })}
    />
    <span class="card-sub">{t(`route.${app.status?.routeMode ?? 'systemProxy'}`)}</span>
  </Card>
{/snippet}

{#snippet whitelist()}
  <Card title={t('home.whitelist')} icon="whitelist" span={wide.has('whitelist')}>
    {#snippet accessory()}
      <Switch
        label={t('whitelist.enabled')}
        checked={app.whitelist.enabled}
        disabled={app.busy['wl:enabled']}
        onchange={(enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })}
      />
    {/snippet}
    <button type="button" class="card-click" onclick={() => navigate('whitelist')}>
      <Value text={`${entries.length}`} />
      <span class="card-sub clip" class:warn-text={whitelistStatus.tone === 'fair'}>{whitelistStatus.text}</span>
    </button>
  </Card>
{/snippet}

{#snippet subscription()}
  <Card title={t('home.profile')} icon="profiles" span={wide.has('subscription')}>
    {#snippet accessory()}
      {#if profile?.updatedAt}<span class="card-note">{t('home.updated', { ago: formatAgo(profile.updatedAt) })}</span>{/if}
      {#if profile?.kind === 'subscription'}
        <button
          type="button"
          class="icon-btn sm"
          title={t('home.update')}
          aria-label={t('home.update')}
          disabled={app.busy[`update:${profile.id}`]}
          onclick={() => act(`update:${profile.id}`, 'update_profile', { id: profile.id })}
        >
          <Icon name="refresh" class={app.busy[`update:${profile.id}`] ? 'spin' : ''} />
        </button>
      {/if}
    {/snippet}
    <button
      type="button"
      class="card-click"
      title={profileTip}
      aria-label={profile ? profileTitle(profile) : t('home.addProfile')}
      onclick={() => navigate('profiles')}
    >
      {#if profile}
        <div class="sub-head">
          <strong class="clip">{profileTitle(profile)}</strong>
          {#if percent != null}<span class="sub-pct">{percent}%</span>{/if}
        </div>
        {#if usage?.total}
          <div class="usage-bar"><span style:width="{percent ?? 0}%"></span></div>
          <div class="sub-meta">
            <span>{formatUsage(used, usage.total)}</span>
            {#if usage.expire}<span>{t('profiles.expire', { date: formatDate(usage.expire) })}</span>{/if}
          </div>
        {:else}
          <span class="card-sub">{profileTip || t('page.profiles')}</span>
        {/if}
      {:else}
        <span class="text-link">{t('home.addProfile')}</span>
      {/if}
    </button>
  </Card>
{/snippet}

{#snippet exitIp()}
  <Card title={t('home.exitIp')} icon="pin" span={wide.has('exitIp')}>
    {#snippet accessory()}
      <button
        type="button"
        class="icon-btn sm"
        title={t('home.refresh')}
        aria-label={t('home.refresh')}
        disabled={app.exitIpLoading}
        onclick={() => refreshExitIp()}><Icon name="refresh" class={app.exitIpLoading ? 'spin' : ''} /></button
      >
    {/snippet}
    <Value text={app.exitIp?.ip ?? (app.exitIpLoading ? '…' : '—')} size="medium" />
    <span class="card-sub">{app.exitIp?.country ?? '—'}</span>
  </Card>
{/snippet}

{#snippet intranetIp()}
  <Card title={t('home.lan')} icon="monitor" span={wide.has('intranetIp')}>
    <Value text={app.lan?.ip ?? '—'} size="small" />
    <span class="card-sub">{app.lan?.interface || 'LAN'}</span>
  </Card>
{/snippet}

{#snippet traffic()}
  <Card title={t('home.traffic')} icon="updown" span={wide.has('traffic')}>
    <Value text={formatBytes((totals?.uploadTotal ?? 0) + (totals?.downloadTotal ?? 0))} />
    <span class="card-sub clip">↑ {formatBytes(totals?.uploadTotal ?? 0)} · ↓ {formatBytes(totals?.downloadTotal ?? 0)}</span>
  </Card>
{/snippet}

{#snippet connections()}
  <Card title={t('home.connections')} icon="link" span={wide.has('connections')}>
    {#snippet accessory()}
      <button type="button" class="icon-btn sm" aria-label={t('page.activity')} onclick={() => navigate('activity')}>
        <Icon name="chevron" />
      </button>
    {/snippet}
    <button type="button" class="card-click" onclick={() => navigate('activity')}>
      <Value text={`${totals?.items.length ?? 0}`} />
      <span class="card-sub">{t('home.requestsTotal', { count: app.requestCount.toLocaleString() })}</span>
    </button>
  </Card>
{/snippet}

{#snippet memory()}
  <Card title={t('home.memory')} icon="chip" span={wide.has('memory')}>
    <Value text={app.memory ? formatBytes(app.memory) : '—'} />
    <span class="card-sub">mihomo</span>
  </Card>
{/snippet}
