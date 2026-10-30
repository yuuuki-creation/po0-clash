<script module>
  import { SvelteSet } from 'svelte/reactivity';

  const expanded = new SvelteSet();
  let touched = false;
</script>

<script>
  import { act, app, testDelay } from '../lib/core.svelte.js';
  import { delayTone, formatDelay, t } from '../lib/i18n.js';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import Page from '../lib/Page.svelte';

  const direct = $derived(app.status?.mode === 'direct');
  const testing = $derived(Object.keys(app.busy).some((key) => key.startsWith('delay:')));
  const showGroups = $derived(!direct && app.groups.length > 0);

  $effect(() => {
    const first = app.groups.find((g) => g.selectable) ?? app.groups[0];
    if (!touched && !expanded.size && first) expanded.add(first.name);
  });

  function toggle(name) {
    touched = true;
    if (expanded.has(name)) expanded.delete(name);
    else expanded.add(name);
  }
</script>

<Page
  title={t('page.proxies')}
  subtitle={app.status?.engine.state === 'running' ? (app.status.currentNode ?? '') : ''}
  fill={!showGroups}
>
  {#snippet actions()}
    <div class="group glass">
      <button
        type="button"
        title={t('proxies.testAll')}
        aria-label={t('proxies.testAll')}
        disabled={!showGroups || testing}
        onclick={() => app.groups.forEach((g) => testDelay(g.name))}
      >
        {#if testing}<span class="spinner"></span>{:else}<Icon name="gauge" />{/if}
      </button>
    </div>
  {/snippet}

  {#if direct}
    <EmptyState icon="route" title={t('proxies.direct')} detail={t('proxies.directHint')} />
  {:else if !app.groups.length}
    <EmptyState icon="globe" title={t('proxies.empty')} detail={t('proxies.emptyHint')} />
  {:else}
    {#each app.groups as group (group.name)}
      {@const open = expanded.has(group.name)}
      <section class="proxy-group">
        <div class="group-head">
          <button type="button" class="grow link-row" aria-expanded={open} onclick={() => toggle(group.name)}>
            <span class="chevron" class:open><Icon name="chevron" /></span>
            <span class="grow">
              <span class="title"><span class="strong">{group.name}</span> <span class="sub">{group.kind}</span></span>
              <span class="sub title">{group.now ?? '—'}</span>
            </span>
          </button>
          <span class="sub mono">{group.nodes.length}</span>
          <button
            type="button"
            class="icon-button"
            title={t('proxies.test')}
            aria-label={t('proxies.test')}
            disabled={app.busy[`delay:${group.name}`]}
            onclick={() => testDelay(group.name)}
          >
            {#if app.busy[`delay:${group.name}`]}<span class="spinner"></span>{:else}<Icon name="gauge" />{/if}
          </button>
        </div>
        {#if open}
          <div class="nodes">
            {#each group.nodes as node (node.name)}
              <button
                type="button"
                class="node"
                class:selected={node.name === group.now}
                disabled={!group.selectable || app.busy[`select:${group.name}`]}
                onclick={() =>
                  node.name !== group.now &&
                  act(`select:${group.name}`, 'select_node', { group: group.name, node: node.name })}
              >
                <span class="title">{node.name}</span>
                <span class="node-meta">
                  <span class="sub">{node.kind}</span>
                  <span class="mono tone-{delayTone(node.delay)}">{formatDelay(node.delay)}</span>
                </span>
              </button>
            {/each}
          </div>
        {/if}
      </section>
    {/each}
  {/if}
</Page>
