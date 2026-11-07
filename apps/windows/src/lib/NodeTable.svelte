<script>
  import { act, app } from './core.svelte.js';
  import DelayButton from './DelayButton.svelte';
  import Icon from './Icon.svelte';
  import { t } from './i18n.js';

  let { group, nodes, tile } = $props();
</script>

<div class="node-grid {tile}">
  {#each nodes as node (node.name)}
    {@const selected = node.name === group.now}
    <div class="node-tile" class:sel={selected} class:ro={!group.selectable}>
      <button
        type="button"
        class="row-hit"
        aria-label={node.name}
        aria-pressed={selected}
        title={node.name}
        disabled={!group.selectable || app.busy[`select:${group.name}`]}
        onclick={() => (!selected || group.kind !== 'Selector') && act(`select:${group.name}`, 'select_node', { group: group.name, node: node.name })}
      ></button>
      <div class="tile-top">
        <span class="tile-name clip">{node.name}</span>
        {#if selected}<span class="tile-check"><Icon name="check" /></span>{/if}
        {#if tile !== 'detailed'}<DelayButton {node} minimal={tile === 'minimal'} />{/if}
      </div>
      {#if tile === 'detailed'}
        <div class="tile-meta">
          <span class="val c-kind clip">{node.kind}</span>
          <DelayButton {node} minimal={false} />
        </div>
      {/if}
    </div>
  {:else}
    <div class="empty-row">{t('proxies.noMatch')}</div>
  {/each}
</div>
