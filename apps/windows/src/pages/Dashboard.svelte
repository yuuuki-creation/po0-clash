<script module>
  let chosenGroup = $state(null);
</script>

<script>
  import { act, app, refreshExitIp, testDelay, testNode } from '../lib/core.svelte.js';
  import { delayTone, formatAgo, formatBytes, formatDate, formatDelay, formatRate, t } from '../lib/i18n.js';
  import Card from '../lib/Card.svelte';
  import Icon from '../lib/Icon.svelte';
  import Menu from '../lib/Menu.svelte';
  import Page from '../lib/Page.svelte';
  import Segmented from '../lib/Segmented.svelte';
  import SpeedChart from '../lib/SpeedChart.svelte';
  import Switch from '../lib/Switch.svelte';
  import Value from '../lib/Value.svelte';

  const engine = $derived(app.status?.engine.state ?? 'stopped');
  const running = $derived(engine === 'running');
  const subtitle = $derived(
    running ? t('status.running', { route: t(`route.${app.status.routeMode}`) }) : t(`status.${engine}`),
  );

  const selectable = $derived(app.groups.filter((g) => g.selectable));
  const group = $derived(
    selectable.find((g) => g.name === chosenGroup) ??
      selectable.find((g) => g.now === app.status?.currentNode) ??
      selectable[0],
  );
  const node = $derived(running && group ? group.nodes.find((n) => n.name === group.now) : null);
  const alternatives = $derived.by(() => {
    if (!node) return [];
    const rank = (n) => (n.delay ? n.delay : n.delay === 0 ? 1e9 : 1e8);
    return group.nodes
      .filter((n) => n.name !== node.name)
      .toSorted((a, b) => rank(a) - rank(b))
      .slice(0, 4);
  });

  const profile = $derived(app.profiles.find((p) => p.selected));
  const usage = $derived(profile?.usage);
  const used = $derived(usage ? usage.upload + usage.download : 0);
  const percent = $derived(usage?.total ? Math.min(100, Math.round((used / usage.total) * 100)) : null);

  const entries = $derived(app.whitelist.entries);
  const failing = $derived(entries.filter((e) => e.result && e.result.outcome !== 'applied').length);
  const lastCheck = $derived(Math.max(0, ...entries.map((e) => e.result?.at ?? 0)));
  const whitelistStatus = $derived.by(() => {
    if (!app.whitelist.enabled) return { tone: '', text: t('home.whitelistOff') };
    if (!entries.length) return { tone: '', text: t('home.noEntries') };
    if (!lastCheck) return { tone: '', text: t('home.pending') };
    if (failing) return { tone: 'fair', text: t('home.issues', { count: failing }) };
    return { tone: 'good', text: t('home.allGood', { ago: formatAgo(lastCheck) }) };
  });

  const totals = $derived(app.totals);
  const select = (name) => act(`select:${group.name}`, 'select_node', { group: group.name, node: name });
  const profileTitle = (p) => (p.kind === 'links' ? t('profiles.links') : p.name);
</script>

<Page title={t('page.dashboard')} {subtitle}>
  {#snippet actions()}
    <div class="tb-group glass">
      <button
        type="button"
        title={t('home.test')}
        aria-label={t('home.test')}
        disabled={!group || app.busy[`delay:${group?.name}`]}
        onclick={() => testDelay(group.name)}
      >
        {#if group && app.busy[`delay:${group.name}`]}<span class="spinner"></span>{:else}<Icon name="bolt" />{/if}
      </button>
    </div>
  {/snippet}

  {#if engine === 'failed'}
    <div class="card failure">
      <Icon name="warning" />
      <div class="grow">
        <span class="strong">{t('status.failed')}</span>
        <span class="sub selectable">{app.status.engine.message}</span>
      </div>
      <button type="button" class="pill" disabled={app.busy.power} onclick={() => act('power', 'start')}
        >{t('home.reconnect')}</button
      >
    </div>
  {/if}

  <div class="dash">
    <Card title={t('home.node')} icon="globe" span>
      {#snippet accessory()}
        {#if selectable.length > 1}
          <Menu
            small
            label={t('home.group')}
            value={group?.name}
            options={selectable.map((g) => ({ value: g.name, label: g.name }))}
            onchange={(name) => (chosenGroup = name)}
          />
        {/if}
      {/snippet}
      <div class="split end">
        <div class="grow">
          <span class="node-name">{node?.name ?? '—'}</span>
          <span class="sub title">
            {#if node}{[node.kind, t('home.nodeMeta', { group: group.name, count: group.nodes.length })]
                .filter(Boolean)
                .join(' · ')}{:else}{t(`status.${engine}`)}{/if}
          </span>
        </div>
        {#if node}
          <div class="split">
            {#if node.delay != null}
              <span class="caption strong tone-{delayTone(node.delay)}" style:font-size="15px"
                ><span class="dot {delayTone(node.delay)}"></span>{formatDelay(node.delay)}</span
              >
            {/if}
            <button
              type="button"
              class="round"
              title={t('home.testNode')}
              aria-label={t('home.testNode')}
              disabled={app.busy[`node:${node.name}`]}
              onclick={() => testNode(node.name)}
            >
              {#if app.busy[`node:${node.name}`]}<span class="spinner"></span>{:else}<Icon name="bolt" />{/if}
            </button>
          </div>
        {/if}
      </div>
      {#if alternatives.length}
        <div class="hr"></div>
        <div class="chips">
          <span class="sub">{t('home.switchTo')}</span>
          {#each alternatives as n (n.name)}
            <button
              type="button"
              class="chip"
              disabled={app.busy[`select:${group.name}`]}
              onclick={() => select(n.name)}
            >
              <span>{n.name}</span>{#if n.delay != null}<span class="mono tone-{delayTone(n.delay)}"
                  >{formatDelay(n.delay)}</span
                >{/if}
            </button>
          {/each}
        </div>
      {/if}
    </Card>

    <Card title={t('home.speed')} icon="chart" span>
      {#snippet accessory()}<span>{t('home.last60')}</span>{/snippet}
      <div class="speed-values">
        <div>
          <Value text={formatRate(app.traffic.down)} />
          <span class="caption"><span class="dot accent"></span>{t('home.download')}</span>
        </div>
        <div>
          <Value text={formatRate(app.traffic.up)} />
          <span class="caption"><span class="dot up"></span>{t('home.upload')}</span>
        </div>
      </div>
      <SpeedChart history={app.history} />
    </Card>

    <Card title={t('home.mode')} icon="branch" span>
      <Segmented
        label={t('home.mode')}
        options={['rule', 'global', 'direct'].map((value) => ({ value, label: t(`mode.${value}`) }))}
        value={app.status?.mode}
        disabled={app.busy.mode || !app.status}
        onchange={(mode) => act('mode', 'set_mode', { mode })}
      />
      <span class="caption">{app.status ? t(`mode.${app.status.mode}Desc`) : ''}</span>
    </Card>

    <Card title={t('home.route')} icon="wifi">
      <Segmented
        label={t('home.route')}
        options={['tun', 'systemProxy'].map((value) => ({ value, label: t(`route.${value}`) }))}
        value={app.status?.routeMode}
        disabled={app.busy.route || !app.status}
        onchange={(routeMode) => act('route', 'set_route_mode', { routeMode })}
      />
      <span class="caption"
        ><span class="dot" class:good={running}></span>{running
          ? t(`home.routeOn.${app.status.routeMode}`)
          : t(`status.${engine}`)}</span
      >
    </Card>

    <Card title={t('home.whitelist')} icon="shield">
      {#snippet accessory()}
        <Switch
          label={t('whitelist.enabled')}
          checked={app.whitelist.enabled}
          disabled={app.busy['wl:enabled']}
          onchange={(enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })}
        />
      {/snippet}
      <Value text={`${entries.length} ${t('home.entryUnit')}`} />
      <button type="button" class="caption link-caption" onclick={() => (app.page = 'whitelist')}
        ><span class="dot {whitelistStatus.tone}"></span><span class="title">{whitelistStatus.text}</span></button
      >
    </Card>

    <Card title={t('home.traffic')} icon="updown">
      <Value text={formatBytes(totals ? totals.uploadTotal + totals.downloadTotal : 0)} />
      <span class="caption">↑ {formatBytes(totals?.uploadTotal ?? 0)} · ↓ {formatBytes(totals?.downloadTotal ?? 0)}</span>
    </Card>

    <Card title={t('home.connections')} icon="link">
      {#snippet accessory()}
        <button type="button" class="plain-button" aria-label={t('page.activity')} onclick={() => (app.page = 'activity')}
          ><Icon name="chevron" /></button
        >
      {/snippet}
      <Value text={`${totals?.items.length ?? 0} ${t('home.connectionUnit')}`.trim()} />
      <span class="caption">{t('home.requestsTotal', { count: app.requestCount.toLocaleString() })}</span>
    </Card>

    <Card title={t('home.memory')} icon="chip">
      <Value text={app.memory ? formatBytes(app.memory) : '—'} />
      <span class="caption">{t('home.memoryCaption')}</span>
    </Card>

    <Card title={t('home.lan')} icon="monitor">
      <Value text={app.lan?.ip ?? '—'} size="small" />
      <span class="caption title">{app.lan?.interface ?? ''}</span>
    </Card>

    <Card title={t('home.profile')} icon="stack" span>
      {#snippet accessory()}
        {#if profile?.updatedAt}<span>{t('home.updated', { ago: formatAgo(profile.updatedAt) })}</span>{/if}
        {#if profile?.kind === 'subscription'}
          <button
            type="button"
            class="round small"
            title={t('home.update')}
            aria-label={t('home.update')}
            disabled={app.busy[`update:${profile.id}`]}
            onclick={() => act(`update:${profile.id}`, 'update_profile', { id: profile.id })}
          >
            {#if app.busy[`update:${profile.id}`]}<span class="spinner"></span>{:else}<Icon name="refresh" />{/if}
          </button>
        {/if}
      {/snippet}
      {#if !profile}
        <button type="button" class="text-button start-aligned" onclick={() => (app.page = 'profiles')}
          >{t('home.addProfile')}</button
        >
      {:else}
        <div class="split spread">
          <span class="title profile-name">{profileTitle(profile)}</span>
          {#if percent != null}<span class="sub mono">{t('home.percent', { percent })}</span>{/if}
        </div>
        {#if percent != null}
          <div class="bar"><span style:width="{percent}%"></span></div>
          <div class="usage">
            <span>{t('home.usedOf', { used: formatBytes(used), total: formatBytes(usage.total) })}</span>
            {#if usage.expire}<span>{t('profiles.expire', { date: formatDate(usage.expire) })}</span>{/if}
          </div>
        {:else}
          <span class="caption">{t('home.noUsage')}</span>
        {/if}
      {/if}
    </Card>

    <Card title={t('home.exitIp')} icon="pin" span>
      {#snippet accessory()}
        <button
          type="button"
          class="round small"
          title={t('home.refresh')}
          aria-label={t('home.refresh')}
          disabled={app.exitIpLoading}
          onclick={() => refreshExitIp()}><Icon name="refresh" /></button
        >
      {/snippet}
      <Value text={app.exitIp?.ip ?? (app.exitIpLoading ? '…' : '—')} size="medium" />
      <span class="caption">{app.exitIp?.country ?? ''}</span>
    </Card>
  </div>
</Page>
