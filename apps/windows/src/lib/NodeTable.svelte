<script>
  import { act, app } from './core.svelte.js';
  import DelayButton from './DelayButton.svelte';
  import { t } from './i18n.js';

  let { group, nodes, tile } = $props();
</script>

{#each nodes as node (node.name)}
  {@const selected = node.name === group.now}
  <div class="row t-node" class:sel={selected} class:ro={!group.selectable}>
    <button
      type="button"
      class="row-hit"
      aria-label={node.name}
      aria-pressed={selected}
      title={node.name}
      disabled={!group.selectable || app.busy[`select:${group.name}`]}
      onclick={() => (!selected || group.kind !== 'Selector') && act(`select:${group.name}`, 'select_node', { group: group.name, node: node.name })}
    ></button>
    <span class="clip">{node.name}</span>
    {#if tile === 'detailed'}<span class="val c-kind clip">{node.kind}</span>{/if}
    <DelayButton {node} minimal={tile === 'minimal'} />
  </div>
{:else}
  <div class="empty-row">{t('proxies.noMatch')}</div>
{/each}
