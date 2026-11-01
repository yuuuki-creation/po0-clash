<script module>
  import { SvelteSet } from 'svelte/reactivity';

  const expanded = new SvelteSet();
  const view = $state({ query: '', tab: null });
  let touched = false;

  /** Opens the page on a group, and clears any filter that could hide it. */
  export function focusGroup(name) {
    view.query = '';
    view.tab = name ?? null;
    if (!name) return;
    touched = true;
    expanded.add(name);
  }
</script>

<script>
  import { tick } from 'svelte';
  import { slide } from 'svelte/transition';
  import { app, resolvedDelay, testDelay } from '../lib/core.svelte.js';
  import { easeIn } from '../lib/easing.js';
  import { formatDelay, t } from '../lib/i18n.js';
  import EmptyState from '../lib/EmptyState.svelte';
  import GroupIcon from '../lib/GroupIcon.svelte';
  import Icon from '../lib/Icon.svelte';
  import Menu from '../lib/Menu.svelte';
  import { motion } from '../lib/motion.svelte.js';
  import NodeTable from '../lib/NodeTable.svelte';
  import Page from '../lib/Page.svelte';
  import Popup from '../lib/Popup.svelte';
  import SectionMenu from '../lib/SectionMenu.svelte';
  import { settings, updateSettings } from '../lib/settings.svelte.js';

  const s = $derived(settings.value);
  const tabs = $derived(s.proxiesLayout === 'tabs');
  const direct = $derived(app.status?.mode === 'direct');
  const testingAny = $derived(Object.keys(app.busy).some((key) => /^(delay|node):/.test(key)));
  const query = $derived(view.query.trim().toLowerCase());
  const hit = (text) => text.toLowerCase().includes(query);

  const rank = (delay) => (delay ? delay : delay === 0 ? 1e9 : 1e8);
  const sorters = {
    profile: null,
    delay: (a, b) => rank(resolvedDelay(a)) - rank(resolvedDelay(b)),
    name: (a, b) => a.name.localeCompare(b.name),
  };

  const groups = $derived(
    app.groups
      .filter((group) => !query || hit(group.name) || group.nodes.some((node) => hit(node.name)))
      .map((group) => {
        let nodes = !query || hit(group.name) ? group.nodes : group.nodes.filter((node) => hit(node.name));
        if (sorters[s.proxiesSort]) nodes = nodes.toSorted(sorters[s.proxiesSort]);
        return { ...group, shown: nodes };
      }),
  );
  const current = $derived(
    groups.find((g) => g.name === view.tab) ?? groups.find((g) => g.selectable && g.now === app.status?.currentNode) ?? groups[0],
  );
  const testingCurrent = $derived(
    !!current && (app.busy[`delay:${current.name}`] || current.nodes.some((node) => app.busy[`node:${node.name}`])),
  );

  let comboButton = $state();
  let comboOpen = $state(false);

  $effect(() => {
    const first = app.groups.find((g) => g.selectable) ?? app.groups[0];
    if (!touched && !expanded.size && first) expanded.add(first.name);
  });

  const currentName = $derived(current?.name);

  $effect(() => {
    if (tabs && currentName) revealSelection('auto');
  });

  function revealSelection(behavior) {
    tick().then(() => {
      document
        .querySelectorAll('.group-pane .sel, .tbl .t-node.sel')
        .forEach((row) => row.scrollIntoView({ block: 'nearest', behavior }));
    });
  }

  function toggle(name) {
    touched = true;
    if (expanded.has(name)) expanded.delete(name);
    else expanded.add(name);
  }

  function locate() {
    const group = app.groups.find((g) => g.selectable && g.now === app.status?.currentNode) ?? app.groups[0];
    if (!group) return;
    focusGroup(group.name);
    revealSelection(motion(1) ? 'smooth' : 'auto');
  }

  const delayOf = (group) => resolvedDelay(group.nodes.find((n) => n.name === group.now) ?? {});

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
      title: t('view.tile'),
      value: s.proxyTileStyle,
      options: ['detailed', 'compact', 'minimal'].map((value) => ({ value, label: t(`tile.${value}`) })),
      onchange: (proxyTileStyle) => updateSettings({ proxyTileStyle }),
    },
    {
      title: t('view.icon'),
      value: s.groupIconStyle,
      options: ['standard', 'iconOnly', 'hidden'].map((value) => ({ value, label: t(`icon.${value}`) })),
      onchange: (groupIconStyle) => updateSettings({ groupIconStyle }),
    },
    {
      close: true,
      value: null,
      options: [{ value: 'testAll', label: t('proxies.testAll'), disabled: testingAny }],
      onchange: () => app.groups.forEach((g) => testDelay(g.name)),
    },
  ]);
</script>

<Page title={t('page.proxies')} capped={false} scroll={!tabs && !direct && !!app.groups.length}>
  {#snippet actions()}
    {#if !direct && app.groups.length}
      <label class="search">
        <Icon name="search" />
        <input bind:value={view.query} aria-label={t('proxies.searchLabel')} placeholder={t('proxies.search')} spellcheck="false" />
      </label>
      <Menu
        label={t('proxies.sort')}
        triggerClass="btn"
        value={s.proxiesSort}
        options={['profile', 'delay', 'name'].map((value) => ({ value, label: t(`sort.${value}`) }))}
        onchange={(proxiesSort) => updateSettings({ proxiesSort })}
      />
      <button type="button" class="icon-btn" title={t('proxies.locate')} aria-label={t('proxies.locate')} onclick={locate}
        ><Icon name="locate" /></button
      >
      <SectionMenu label={t('proxies.view')} sections={viewSections}>
        {#snippet trigger()}<Icon name="moreH" />{/snippet}
      </SectionMenu>
      {#if tabs}
        <button type="button" class="btn" disabled={!current || testingCurrent} onclick={() => testDelay(current.name)}>
          {#if testingCurrent}<span class="ring"></span>{t('proxies.testing')}{:else}{t('proxies.test')}{/if}
        </button>
      {/if}
    {/if}
  {/snippet}

  {#if direct}
    <EmptyState icon="branch" title={t('proxies.direct')} />
  {:else if !app.groups.length}
    <EmptyState icon="proxies" title={t('proxies.empty')} />
  {:else if tabs}
    <div class="groups-bar">
      <button
        bind:this={comboButton}
        type="button"
        class="btn combo"
        aria-haspopup="listbox"
        aria-expanded={comboOpen}
        aria-label={t('home.group')}
        onclick={() => (comboOpen = !comboOpen)}
      >
        <span class="clip">{current?.name ?? t('proxies.noMatch')}</span>
        <span class="val clip">{current?.now ?? ''}</span>
        <Icon name="chevDown" class="chev-d" />
      </button>
    </div>
    <div class="split">
      <section class="group-pane" aria-label={t('home.group')}>
        {#each groups as group (group.name)}
          <button
            type="button"
            class="row two"
            class:sel={group.name === current?.name}
            title={group.name}
            aria-current={group.name === current?.name}
            onclick={() => (view.tab = group.name)}
          >
            <GroupIcon icon={group.icon} name={group.name} style={s.groupIconStyle} />
            <span class="val clip">{group.now || '—'}</span>
          </button>
        {:else}
          <div class="empty-row">{t('proxies.noMatch')}</div>
        {/each}
      </section>
      <section class="tbl {s.proxiesDensity} {s.proxyTileStyle}" aria-label={current?.name}>
        <div class="row t-node thead">
          <span>{t('table.name')}</span>
          {#if s.proxyTileStyle === 'detailed'}<span class="c-kind">{t('table.type')}</span>{/if}
          <span>{t('table.delay')}</span>
        </div>
        {#if current}
          {#key current.name}
            <NodeTable group={current} nodes={current.shown} tile={s.proxyTileStyle} />
          {/key}
        {:else}
          <div class="empty-row">{t('proxies.noMatch')}</div>
        {/if}
      </section>
    </div>
  {:else}
    {#each groups as group (group.name)}
      {@const open = expanded.has(group.name) || !!query}
      {@const delay = delayOf(group)}
      <section class="tbl auto pgroup {s.proxiesDensity} {s.proxyTileStyle}" aria-label={group.name}>
        <div class="row pg-head">
          <button
            type="button"
            class="row-hit"
            aria-expanded={open}
            aria-label={open ? t('proxies.collapse') : t('proxies.expand')}
            disabled={!!query}
            onclick={() => toggle(group.name)}
          ></button>
          <span class="pg-name"><GroupIcon icon={group.icon} name={group.name} style={s.groupIconStyle} /></span>
          <span class="val c-kind">{group.kind}</span>
          <span class="grow"></span>
          {#if !open && group.now}
            <span class="val clip">{group.now}</span>
            {#if delay != null}<span class="val">{formatDelay(delay)}</span>{/if}
          {/if}
          <button
            type="button"
            class="icon-btn"
            title={t('proxies.test')}
            aria-label={t('proxies.test')}
            disabled={app.busy[`delay:${group.name}`] || group.nodes.some((node) => app.busy[`node:${node.name}`])}
            onclick={() => testDelay(group.name)}
          >
            {#if app.busy[`delay:${group.name}`]}<span class="ring"></span>{:else}<Icon name="bolt" />{/if}
          </button>
          <span class="pg-chev" class:open><Icon name="chevDown" class="chev" /></span>
        </div>
        {#if open}
          <div transition:slide={{ duration: motion(250), easing: easeIn }}>
            <NodeTable {group} nodes={group.shown} tile={s.proxyTileStyle} />
          </div>
        {/if}
      </section>
    {:else}
      <EmptyState icon="search" title={t('proxies.noMatch')} />
    {/each}
  {/if}
</Page>

{#if comboOpen}
  <Popup
    anchor={comboButton}
    role="listbox"
    label={t('home.group')}
    align="start"
    matchWidth
    class="group-menu"
    onclose={() => (comboOpen = false)}
  >
    {#each groups as group (group.name)}
      <button
        type="button"
        role="option"
        class:sel={group.name === current?.name}
        aria-selected={group.name === current?.name}
        title={group.name}
        onclick={() => {
          view.tab = group.name;
          comboOpen = false;
        }}
      >
        <span class="name"><GroupIcon icon={group.icon} name={group.name} style={s.groupIconStyle} size={18} /></span>
        <span class="val clip">{group.now ?? ''}</span>
      </button>
    {/each}
  </Popup>
{/if}
