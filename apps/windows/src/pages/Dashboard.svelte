<script module>
  let chosenGroup = $state(null);
</script>

<script>
  import { act, app, refreshExitIp, testDelay } from '../lib/core.svelte.js';
  import { arrangeCards, displayOrder, moveCard } from '../lib/dashboard-cards.js';
  import { formatAgo, formatBytes, formatDate, formatDelay, formatElapsed, formatRate, t } from '../lib/i18n.js';
  import DelayButton from '../lib/DelayButton.svelte';
  import Icon from '../lib/Icon.svelte';
  import { navigate, rowIn, rowOut } from '../lib/motion.svelte.js';
  import Page from '../lib/Page.svelte';
  import SectionMenu from '../lib/SectionMenu.svelte';
  import Segmented from '../lib/Segmented.svelte';
  import { settings, updateSettings } from '../lib/settings.svelte.js';
  import SpeedChart from '../lib/SpeedChart.svelte';
  import Switch from '../lib/Switch.svelte';
  import { focusGroup } from './Proxies.svelte';

  const engine = $derived(app.status?.engine.state ?? 'stopped');
  const running = $derived(engine === 'running');
  const starting = $derived(engine === 'starting' || !!app.busy.power);
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
  const powerState = $derived(starting ? 'connecting' : running ? 'disconnect' : engine === 'failed' ? 'reconnect' : 'connect');

  const selectable = $derived(app.groups.filter((g) => g.selectable));
  const group = $derived(
    selectable.find((g) => g.name === chosenGroup) ??
      selectable.find((g) => g.now === app.status?.currentNode) ??
      selectable[0],
  );
  const node = $derived(running && group ? group.nodes.find((n) => n.name === group.now) : null);
  const rank = (n) => (n.delay ? n.delay : n.delay === 0 ? 1e9 : 1e8);
  const nodeSections = $derived.by(() => {
    if (!node) return [];
    const nodes = {
      title: t('home.switchTo'),
      value: node.name,
      close: true,
      options: group.nodes
        .toSorted((a, b) => rank(a) - rank(b))
        .map((n) => ({ value: n.name, label: n.name, detail: formatDelay(n.delay) })),
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
  const columns = $derived(arrangeCards(cards));
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

  <section class="group">
    <div class="row status">
      <span class="dot {statusTone}"></span>
      <div class="grow status-text">
        <div class="status-main">
          <strong>{t(`status.${engine}`)}</strong>
          {#if app.connectedAt}<span class="val mono">{formatElapsed(now - app.connectedAt)}</span>{/if}
        </div>
        {#if engine === 'failed'}<span class="bad-text selectable">{app.status.engine.message}</span>{/if}
      </div>
      <button
        type="button"
        class="btn power"
        class:primary={!running && !starting}
        disabled={starting || !app.status}
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
    </div>
  </section>

  {#if editing}
    <section class="group">
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
    <div class="cols">
      {#each columns as sections, i (i)}
        <div class="col">
          {#each sections as section, s (s)}
            <section class="group">
              {#each section.cards as id (id)}
                {@render rows[id]()}
              {/each}
            </section>
          {/each}
        </div>
      {/each}
    </div>
  {/if}
</Page>

{#snippet currentNode()}
  <div class="row">
    <button type="button" class="row-hit" aria-label={t('home.node')} onclick={() => openGroup(group?.name)}></button>
    <span class="grow clip">{t('home.node')}</span>
    {#if node}
      <SectionMenu label={t('home.switchTo')} sections={nodeSections} triggerClass="val-menu">
        {#snippet trigger()}<span class="clip">{node.name}</span><Icon name="chevDown" class="chev-d" />{/snippet}
      </SectionMenu>
      <DelayButton {node} />
    {:else}
      <span class="val">—</span>
    {/if}
    <Icon name="chevron" class="chev" />
  </div>
{/snippet}

{#snippet mode()}
  <div class="row">
    <span class="grow clip">{t('home.mode')}</span>
    <Segmented
      label={t('home.mode')}
      options={['rule', 'global', 'direct'].map((value) => ({ value, label: t(`mode.${value}`) }))}
      value={app.status?.mode}
      disabled={app.busy.mode || !app.status}
      onchange={(mode) => act('mode', 'set_mode', { mode })}
    />
  </div>
{/snippet}

{#snippet takeover()}
  <div class="row">
    <span class="grow clip">{t('home.route')}</span>
    <Segmented
      label={t('home.route')}
      options={['tun', 'systemProxy'].map((value) => ({ value, label: t(`route.${value}`) }))}
      value={app.status?.routeMode}
      disabled={app.busy.route || !app.status}
      onchange={(routeMode) => act('route', 'set_route_mode', { routeMode })}
    />
  </div>
{/snippet}

{#snippet whitelist()}
  <div class="row">
    <button type="button" class="row-hit" aria-label={t('home.whitelist')} onclick={() => navigate('whitelist')}></button>
    <span class="grow clip">{t('home.whitelist')}</span>
    <span class="val clip" class:bad-text={whitelistStatus.tone === 'fair'}>{whitelistStatus.text}</span>
    <Switch
      label={t('whitelist.enabled')}
      checked={app.whitelist.enabled}
      disabled={app.busy['wl:enabled']}
      onchange={(enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })}
    />
    <Icon name="chevron" class="chev" />
  </div>
{/snippet}

{#snippet subscription()}
  <div class="row" title={profileTip}>
    <button
      type="button"
      class="row-hit"
      aria-label={profile ? profileTitle(profile) : t('home.addProfile')}
      onclick={() => navigate('profiles')}
    ></button>
    {#if profile}
      <span class="grow clip">{profileTitle(profile)}</span>
      {#if usage?.total}<span class="val">{formatBytes(used)} / {formatBytes(usage.total)}</span>{/if}
      {#if profile.kind === 'subscription'}
        <button
          type="button"
          class="icon-btn"
          title={t('home.update')}
          aria-label={t('home.update')}
          disabled={app.busy[`update:${profile.id}`]}
          onclick={() => act(`update:${profile.id}`, 'update_profile', { id: profile.id })}
          ><Icon name="refresh" class={app.busy[`update:${profile.id}`] ? 'spin' : ''} /></button
        >
      {/if}
    {:else}
      <span class="grow clip">{t('home.addProfile')}</span>
    {/if}
    <Icon name="chevron" class="chev" />
  </div>
{/snippet}

{#snippet exitIp()}
  <div class="row">
    <span class="grow clip">{t('home.exitIp')}</span>
    <span class="val selectable">{app.exitIp?.ip ?? (app.exitIpLoading ? '…' : '—')}</span>
    {#if app.exitIp?.country}<span class="val">{app.exitIp.country}</span>{/if}
    <button
      type="button"
      class="icon-btn"
      title={t('home.refresh')}
      aria-label={t('home.refresh')}
      disabled={app.exitIpLoading}
      onclick={() => refreshExitIp()}><Icon name="refresh" class={app.exitIpLoading ? 'spin' : ''} /></button
    >
  </div>
{/snippet}

{#snippet intranetIp()}
  <div class="row" title={app.lan?.interface ?? ''}>
    <span class="grow clip">{t('home.lan')}</span>
    <span class="val selectable">{app.lan?.ip ?? '—'}</span>
  </div>
{/snippet}

{#snippet speed()}
  <div class="row">
    <span class="grow clip">{t('home.speed')}</span>
    <span class="rate dn"><Icon name="down" />{formatRate(app.traffic.down)}</span>
    <span class="rate up"><Icon name="up" />{formatRate(app.traffic.up)}</span>
  </div>
  <SpeedChart history={app.history} />
{/snippet}

{#snippet traffic()}
  <div class="row">
    <span class="grow clip">{t('home.traffic')}</span>
    <span class="rate dn"><Icon name="down" />{formatBytes(totals?.downloadTotal ?? 0)}</span>
    <span class="rate up"><Icon name="up" />{formatBytes(totals?.uploadTotal ?? 0)}</span>
  </div>
{/snippet}

{#snippet connections()}
  <button
    type="button"
    class="row"
    title={t('home.requestsTotal', { count: app.requestCount.toLocaleString() })}
    onclick={() => navigate('activity')}
  >
    <span class="grow clip">{t('home.connections')}</span>
    <span class="val">{totals?.items.length ?? 0}</span>
    <Icon name="chevron" class="chev" />
  </button>
{/snippet}

{#snippet memory()}
  <div class="row">
    <span class="grow clip">{t('home.memory')}</span>
    <span class="val">{app.memory ? formatBytes(app.memory) : '—'}</span>
  </div>
{/snippet}
