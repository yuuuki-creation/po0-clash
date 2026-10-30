<script module>
  import { SvelteSet } from 'svelte/reactivity';

  const expanded = new SvelteSet();
  const view = $state({ query: '', sort: 'default', layout: 'standard' });
  let touched = false;
</script>

<script>
  import { tick } from 'svelte';
  import { act, app, testDelay, testNode } from '../lib/core.svelte.js';
  import { delayTone, formatDelay, t } from '../lib/i18n.js';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import Menu from '../lib/Menu.svelte';
  import Page from '../lib/Page.svelte';

  const direct = $derived(app.status?.mode === 'direct');
  const testing = $derived(Object.keys(app.busy).some((key) => key.startsWith('delay:')));
  const query = $derived(view.query.trim().toLowerCase());

  const rank = (delay) => (delay ? delay : delay === 0 ? 1e9 : 1e8);
  const sorters = {
    default: null,
    delay: (a, b) => rank(a.delay) - rank(b.delay),
    name: (a, b) => a.name.localeCompare(b.name),
  };

  const groups = $derived(
    app.groups
      .map((group) => {
        let nodes = query ? group.nodes.filter((n) => n.name.toLowerCase().includes(query)) : group.nodes;
        if (sorters[view.sort]) nodes = nodes.toSorted(sorters[view.sort]);
        return { ...group, shown: nodes };
      })
      .filter((group) => !query || group.shown.length),
  );

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
    touched = true;
    expanded.add(group.name);
    await tick();
    document
      .querySelector(`[data-group="${CSS.escape(group.name)}"] .node.selected`)
      ?.scrollIntoView({ block: 'center', behavior: 'smooth' });
  }

  const delayOf = (group) => group.nodes.find((n) => n.name === group.now)?.delay;
</script>

<Page
  title={t('page.proxies')}
  subtitle={app.groups.length ? t('proxies.groups', { count: app.groups.length }) : ''}
  fill={direct || !groups.length}
>
  {#snippet actions()}
    <label class="search glass">
      <Icon name="search" />
      <input bind:value={view.query} aria-label={t('proxies.search')} placeholder={t('proxies.search')} spellcheck="false" />
    </label>
    <div class="tb-group glass">
      <Menu
        label={t('proxies.sort')}
        value={view.sort}
        options={['default', 'delay', 'name'].map((value) => ({ value, label: t(`sort.${value}`) }))}
        onchange={(sort) => (view.sort = sort)}
      >
        {#snippet trigger()}<Icon name="sort" />{/snippet}
      </Menu>
      <Menu
        label={t('proxies.layout')}
        value={view.layout}
        options={['standard', 'compact', 'list'].map((value) => ({ value, label: t(`layout.${value}`) }))}
        onchange={(layout) => (view.layout = layout)}
      >
        {#snippet trigger()}<Icon name="grid" />{/snippet}
      </Menu>
      <button
        type="button"
        title={t('proxies.locate')}
        aria-label={t('proxies.locate')}
        disabled={direct || !app.groups.length}
        onclick={locate}><Icon name="locate" /></button
      >
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
  {:else if !groups.length}
    <EmptyState icon="search" title={t('proxies.noMatch')} detail={view.query} />
  {:else}
    {#each groups as group (group.name)}
      {@const open = expanded.has(group.name) || !!query}
      {@const delay = delayOf(group)}
      <section class="pgroup" aria-label={group.name} data-group={group.name}>
        <div class="pg-head">
          <div class="grow">
            <span class="pg-name"><span>{group.name}</span><span class="tag">{group.kind}</span></span>
            <span class="sub title"
              >{group.now ? `${group.now} · ` : ''}{t('proxies.nodes', { count: group.nodes.length })}</span
            >
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
            disabled={app.busy[`delay:${group.name}`]}
            onclick={() => testDelay(group.name)}
          >
            {#if app.busy[`delay:${group.name}`]}<span class="spinner"></span>{:else}<Icon name="bolt" />{/if}
          </button>
          <button
            type="button"
            class="round"
            title={open ? t('proxies.collapse') : t('proxies.expand')}
            aria-label={open ? t('proxies.collapse') : t('proxies.expand')}
            aria-expanded={open}
            disabled={!!query}
            onclick={() => toggle(group.name)}><span class="chevron-wrap" class:flip={open}><Icon name="chevron-down" /></span></button
          >
        </div>
        {#if open}
          <div class="nodes" class:compact={view.layout === 'compact'} class:list={view.layout === 'list'}>
            {#each group.shown as node (node.name)}
              {@const selected = node.name === group.now}
              <div class="node" class:selected>
                <button
                  type="button"
                  class="node-select"
                  aria-label={node.name}
                  aria-pressed={selected}
                  disabled={!group.selectable || app.busy[`select:${group.name}`]}
                  onclick={() =>
                    !selected && act(`select:${group.name}`, 'select_node', { group: group.name, node: node.name })}
                ></button>
                <span class="node-top"><span>{node.name}</span>{#if selected}<Icon name="check" />{/if}</span>
                <span class="node-meta">
                  <span>{node.kind}</span>
                  <button
                    type="button"
                    class="delay-button tone-{delayTone(node.delay)}"
                    title={t('proxies.testNode')}
                    aria-label={t('proxies.testNode')}
                    disabled={app.busy[`node:${node.name}`]}
                    onclick={() => testNode(node.name)}
                  >
                    {#if app.busy[`node:${node.name}`]}<span class="spinner"></span>{:else if node.delay != null}{formatDelay(
                        node.delay,
                      )}{:else}<Icon name="bolt" />{/if}
                  </button>
                </span>
              </div>
            {/each}
          </div>
        {/if}
      </section>
    {/each}
  {/if}
</Page>
