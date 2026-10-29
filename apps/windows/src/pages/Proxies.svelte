<script>
  import { SvelteSet } from 'svelte/reactivity';
  import { act, app } from '../lib/core.svelte.js';
  import { t } from '../lib/i18n.js';

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
    <section class="card group">
      <div class="group-head">
        <button type="button" class="plain grow" aria-expanded={expanded.has(group.name)} onclick={() => toggle(group.name)}>
          <span class="chevron" class:open={expanded.has(group.name)} aria-hidden="true"></span>
          <span class="grow-text">
            <span class="title">{group.name}</span>
            <span class="sub">{group.kind}{group.now ? ` · ${group.now}` : ''}</span>
          </span>
        </button>
        <button type="button" disabled={app.busy[`delay:${group.name}`]} onclick={() => testDelay(group.name)}
          >{t('proxies.test')}</button
        >
      </div>
      {#if expanded.has(group.name)}
        <ul class="nodes">
          {#each group.nodes as node (node.name)}
            <li>
              <button
                type="button"
                class="node"
                class:current={node.name === group.now}
                disabled={!group.selectable || app.busy[`select:${group.name}`]}
                onclick={() => act(`select:${group.name}`, 'select_node', { group: group.name, node: node.name })}
              >
                <span class="node-name">{node.name}</span>
                <span class="sub">{node.kind}</span>
                <span class="delay {delayClass(node.delay)}">{delayText(node.delay)}</span>
              </button>
            </li>
          {/each}
        </ul>
      {/if}
    </section>
  {/each}
{/if}
