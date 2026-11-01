<script module>
  import { SvelteSet } from 'svelte/reactivity';

  const expanded = new SvelteSet();
  const view = $state({ query: '', tab: null });
  let touched = false;
</script>

<script>
  import { tick } from 'svelte';
  import { slide } from 'svelte/transition';
  import { app, testDelay } from '../lib/core.svelte.js';
  import { delayTone, formatDelay, t } from '../lib/i18n.js';
  import EmptyState from '../lib/EmptyState.svelte';
  import GroupIcon from '../lib/GroupIcon.svelte';
  import Icon from '../lib/Icon.svelte';
  import Menu from '../lib/Menu.svelte';
  import { motion } from '../lib/motion.svelte.js';
  import Page from '../lib/Page.svelte';
  import SectionMenu from '../lib/SectionMenu.svelte';
  import ProxyNode from '../lib/ProxyNode.svelte';
  import { settings, updateSettings } from '../lib/settings.svelte.js';
  import '../styles/proxies.css';

  const s = $derived(settings.value);
  const tabs = $derived(s.proxiesLayout === 'tabs');
  const direct = $derived(app.status?.mode === 'direct');
  const testing = $derived(Object.keys(app.busy).some((key) => /^(delay|node):/.test(key)));
  const query = $derived(view.query.trim().toLowerCase());

  const rank = (delay) => (delay ? delay : delay === 0 ? 1e9 : 1e8);
  const sorters = {
    profile: null,
    delay: (a, b) => rank(a.delay) - rank(b.delay),
    name: (a, b) => a.name.localeCompare(b.name),
  };

  const groups = $derived(
    app.groups
      .map((group) => {
        let nodes =
          query && !group.name.toLowerCase().includes(query)
            ? group.nodes.filter((n) => n.name.toLowerCase().includes(query))
            : group.nodes;
        if (sorters[s.proxiesSort]) nodes = nodes.toSorted(sorters[s.proxiesSort]);
        return { ...group, shown: nodes };
      }),
  );
  const current = $derived(
    groups.find((g) => g.name === view.tab) ?? groups.find((g) => g.now === app.status?.currentNode) ?? groups[0],
  );
  const shownGroups = $derived(tabs ? (current ? [current] : []) : groups.filter((group) => !query || group.shown.length));

  $effect(() => {
    const first = app.groups.find((g) => g.selectable) ?? app.groups[0];
    if (!touched && !expanded.size && first) expanded.add(first.name);
  });

  function toggle(name) {
    touched = true;
    if (expanded.has(name)) expanded.delete(name);
    else expanded.add(name);
  }

  async function locate() {
    const group = app.groups.find((g) => g.selectable && g.now === app.status?.currentNode) ?? app.groups[0];
    if (!group) return;
    view.query = '';
    view.tab = group.name;
    touched = true;
    expanded.add(group.name);
    await tick();
    document
      .querySelector(`[data-group="${CSS.escape(group.name)}"] .node.selected`)
      ?.scrollIntoView({ block: 'center', behavior: motion(1) ? 'smooth' : 'instant' });
  }

  function navigateGroup(event, index) {
    let next;
    if (event.key === 'ArrowRight') next = (index + 1) % groups.length;
    else if (event.key === 'ArrowLeft') next = (index + groups.length - 1) % groups.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = groups.length - 1;
    else return;
    event.preventDefault();
    view.tab = groups[next].name;
    event.currentTarget.parentElement.children[next].focus();
  }

  const delayOf = (group) => group.nodes.find((n) => n.name === group.now)?.delay;
  const viewSections = $derived([
    {
      title: t('view.layout'),
      value: s.proxiesLayout,
      options: ['tabs', 'list'].map((value) => ({ value, label: t(`layout.${value}`) })),
      onchange: (proxiesLayout) => updateSettings({ proxiesLayout }),
    },
    {
      title: t('view.density'),
      value: s.proxiesDensity,
      options: ['loose', 'standard', 'tight'].map((value) => ({ value, label: t(`density.${value}`) })),
      onchange: (proxiesDensity) => updateSettings({ proxiesDensity }),
    },
    {
      title: t('view.icon'),
      value: s.groupIconStyle,
      options: ['standard', 'iconOnly', 'hidden'].map((value) => ({ value, label: t(`icon.${value}`) })),
      onchange: (groupIconStyle) => updateSettings({ groupIconStyle }),
    },
    {
      title: t('view.tile'),
      value: s.proxyTileStyle,
      options: ['detailed', 'compact', 'minimal'].map((value) => ({ value, label: t(`tile.${value}`) })),
      onchange: (proxyTileStyle) => updateSettings({ proxyTileStyle }),
    },
  ]);
</script>

<Page
  title={t('page.proxies')}
  subtitle={app.groups.length ? t('proxies.groups', { count: app.groups.length }) : ''}
  fill={direct || !app.groups.length}
>
  {#snippet actions()}
    <div class="tb-group glass">
      <button
        type="button"
        title={t('proxies.testAll')}
        aria-label={t('proxies.testAll')}
        disabled={direct || !app.groups.length || testing}
        onclick={() => app.groups.forEach((g) => testDelay(g.name))}
      >
        {#if testing}<span class="spinner"></span>{:else}<Icon name="bolt" />{/if}
      </button>
    </div>
  {/snippet}

  {#if direct}
    <EmptyState icon="branch" title={t('proxies.direct')} detail={t('proxies.directHint')} />
  {:else if !app.groups.length}
    <EmptyState icon="globe" title={t('proxies.empty')} detail={t('proxies.emptyHint')} />
  {:else}
    <div class="proxy-workspace">
      {#if tabs}
        <div class="group-tabs" role="tablist" aria-label={t('page.proxies')}>
          {#each groups as group, index (group.name)}
            <button
              type="button"
              role="tab"
              id={`proxy-tab-${index}`}
              aria-controls={`proxy-panel-${index}`}
              tabindex={group.name === current?.name ? 0 : -1}
              aria-selected={group.name === current?.name}
              class:on={group.name === current?.name}
              title={group.name}
              aria-label={group.name}
              onclick={() => (view.tab = group.name)}
              onkeydown={(event) => navigateGroup(event, index)}
            >
              <span class="group-tab-name">
                <GroupIcon icon={group.icon} name={group.name} style={s.groupIconStyle} size={16} />
                <span class="group-count">{group.nodes.length}</span>
              </span>
              <span class="group-current" title={group.now}>{group.now || '—'}</span>
            </button>
          {/each}
        </div>
      {/if}
      <div class="proxy-tools" role="toolbar" aria-label={t('proxies.search')}>
        <label class="search glass">
          <Icon name="search" />
          <input bind:value={view.query} aria-label={t('proxies.search')} placeholder={t('proxies.search')} spellcheck="false" />
        </label>
        <div class="tb-group glass">
          <Menu
            label={t('proxies.sort')}
            value={s.proxiesSort}
            options={['profile', 'delay', 'name'].map((value) => ({ value, label: t(`sort.${value}`) }))}
            onchange={(proxiesSort) => updateSettings({ proxiesSort })}
          >
            {#snippet trigger()}
              <span class="trigger-label"><Icon name="sort" />{t(`sort.${s.proxiesSort}`)}</span>
            {/snippet}
          </Menu>
          <SectionMenu label={t('proxies.layout')} sections={viewSections}>
            {#snippet trigger()}<Icon name="grid" />{/snippet}
          </SectionMenu>
          <button type="button" title={t('proxies.locate')} aria-label={t('proxies.locate')} onclick={locate}
            ><Icon name="locate" /></button
          >
        </div>
      </div>
      {#each shownGroups as group (group.name)}
        {@const open = tabs || expanded.has(group.name) || !!query}
        {@const delay = delayOf(group)}
        <section
          class="pgroup"
          aria-label={group.name}
          role={tabs ? 'tabpanel' : undefined}
          id={`proxy-panel-${groups.indexOf(group)}`}
          aria-labelledby={tabs ? `proxy-tab-${groups.indexOf(group)}` : undefined}
          data-group={group.name}
        >
          <div class="pg-head">
            <div class="grow">
              <span class="pg-name"
                ><GroupIcon icon={group.icon} name={group.name} style={s.groupIconStyle} size={20} /><span class="tag"
                  >{group.kind}</span
                ></span
              >
              <span class="sub">{t('proxies.nodes', { count: group.nodes.length })}</span>
            </div>
            {#if !open && group.now}
              <span class="pg-now">{group.now}</span>
              {#if delay != null}<span class="sub mono strong tone-{delayTone(delay)}">{formatDelay(delay)}</span>{/if}
            {/if}
            <button
              type="button"
              class="round"
              title={t('proxies.test')}
              aria-label={t('proxies.test')}
              disabled={app.busy[`delay:${group.name}`] || group.nodes.some((node) => app.busy[`node:${node.name}`])}
              onclick={() => testDelay(group.name)}
            >
              {#if app.busy[`delay:${group.name}`]}<span class="spinner"></span>{:else}<Icon name="bolt" />{/if}
            </button>
            {#if !tabs}
              <button
                type="button"
                class="round"
                title={open ? t('proxies.collapse') : t('proxies.expand')}
                aria-label={open ? t('proxies.collapse') : t('proxies.expand')}
                aria-expanded={open}
                disabled={!!query}
                onclick={() => toggle(group.name)}><span class="chevron-wrap" class:flip={open}><Icon name="chevron-down" /></span></button
              >
            {/if}
          </div>
          {#if open && group.now}
            <div class="pg-selection">
              <span class="dot accent"></span><span class="sub">{t('proxies.current')}</span>
              <strong class="title" title={group.now}>{group.now}</strong>
              {#if delay != null}<span class="mono tone-{delayTone(delay)}">{formatDelay(delay)}</span>{/if}
            </div>
          {/if}
          {#if app.busy[`delay:${group.name}`]}
            <div class="test-status" role="status">
              <span class="spinner" aria-hidden="true"></span>{t('proxies.testingGroup', { count: group.nodes.length })}
              <span class="test-progress" aria-hidden="true"></span>
            </div>
          {/if}
          {#if open}
            <div class="nodes {s.proxiesDensity}" transition:slide={{ duration: motion(260) }}>
              {#each group.shown as node (node.name)}
                <ProxyNode {group} {node} style={s.proxyTileStyle} />
              {:else}
                <div class="proxy-no-match"><EmptyState icon="search" title={t('proxies.noMatch')} detail={view.query} /></div>
              {/each}
            </div>
          {/if}
        </section>
      {:else}
        <EmptyState icon="search" title={t('proxies.noMatch')} detail={view.query} />
      {/each}
    </div>
  {/if}
</Page>
