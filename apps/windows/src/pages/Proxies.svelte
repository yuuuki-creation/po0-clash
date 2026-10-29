<script>
  import { SvelteSet } from 'svelte/reactivity';
  import { act, app } from '../lib/core.svelte.js';
  import { t } from '../lib/i18n.js';
  import Icon from '../lib/Icon.svelte';

  const expanded = new SvelteSet();
  let touched = false;

  $effect(() => {
    if (touched || expanded.size) return;
    const first = app.groups.find((g) => g.selectable) ?? app.groups[0];
    if (first) expanded.add(first.name);
  });

  function toggle(name) {
    touched = true;
    if (expanded.has(name)) expanded.delete(name);
    else expanded.add(name);
  }

  async function testDelay(name) {
    const group = await act(`delay:${name}`, 'test_delay', { group: name });
    if (group) app.groups = app.groups.map((g) => (g.name === name ? group : g));
  }

  function delayClass(delay) {
    if (delay == null) return '';
    if (delay === 0) return 'bad';
    return delay < 300 ? 'good' : delay < 800 ? 'fair' : 'bad';
  }

  const delayText = (delay) => (delay == null ? '' : delay === 0 ? t('proxies.timeout') : `${delay} ms`);
</script>

{#if app.status?.engine.state !== 'running'}
  <p class="empty">{t('proxies.notRunning')}</p>
{:else if !app.groups.length}
  <p class="empty">{t('proxies.empty')}</p>
{:else}
  {#each app.groups as group (group.name)}
    <div class="section-title">
      <span>{group.kind}</span>
      <button
        type="button"
        class="text-button"
        disabled={app.busy[`delay:${group.name}`]}
        onclick={() => testDelay(group.name)}>{t('proxies.test')}</button
      >
    </div>
    <div class="group">
      <button type="button" class="row" aria-expanded={expanded.has(group.name)} onclick={() => toggle(group.name)}>
        <span class="grow">
          <span class="title">{group.name}</span>
          {#if group.now}<span class="sub title">{group.now}</span>{/if}
        </span>
        <span class="chevron" class:open={expanded.has(group.name)}><Icon name="chevron" /></span>
      </button>
      {#if expanded.has(group.name)}
        {#each group.nodes as node (node.name)}
          <button
            type="button"
            class="row"
            disabled={!group.selectable || app.busy[`select:${group.name}`]}
            onclick={() => act(`select:${group.name}`, 'select_node', { group: group.name, node: node.name })}
          >
            <span class="check">{#if node.name === group.now}<Icon name="check" />{/if}</span>
            <span class="grow">
              <span class="title">{node.name}</span>
              <span class="sub">{node.kind}</span>
            </span>
            <span class="delay {delayClass(node.delay)}">{delayText(node.delay)}</span>
          </button>
        {/each}
      {/if}
    </div>
  {/each}
{/if}
