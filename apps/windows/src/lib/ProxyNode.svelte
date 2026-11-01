<script>
  import { act, app, isTestingNode } from './core.svelte.js';
  import DelayButton from './DelayButton.svelte';
  import Icon from './Icon.svelte';
  import { pop } from './motion.svelte.js';

  let { group, node, style = 'detailed' } = $props();
  const selected = $derived(node.name === group.now);
  const testing = $derived(isTestingNode(node.name));
</script>

<div class="node" class:selected class:testing class:inline={style !== 'detailed'}>
  <button
    type="button"
    class="node-select"
    aria-label={node.name}
    aria-pressed={selected}
    title={node.name}
    disabled={!group.selectable || app.busy[`select:${group.name}`]}
    onclick={() => !selected && act(`select:${group.name}`, 'select_node', { group: group.name, node: node.name })}
  ></button>
  <span class="node-top">
    <span>{node.name}</span>
    {#if selected}<span class="check-in" in:pop={{ from: 0.4, y: 0 }}><Icon name="check" /></span>{/if}
  </span>
  <span class="node-meta">
    {#if style === 'detailed'}<span>{node.kind}</span>{/if}
    <DelayButton {node} minimal={style === 'minimal'} />
  </span>
</div>
