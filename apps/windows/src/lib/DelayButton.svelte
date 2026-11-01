<script>
  import { app, isTestingNode, testNode } from './core.svelte.js';
  import { delayTone, formatDelay, t } from './i18n.js';
  import Icon from './Icon.svelte';
  import '../styles/delay.css';

  let { node, minimal = false } = $props();
  const testing = $derived(isTestingNode(node.name));
  const revision = $derived(app.delayResults[node.name] ?? 0);
</script>

<button
  type="button"
  class="delay-button tone-{delayTone(node.delay)}"
  class:testing
  title={`${t('proxies.testNode')} · ${node.name}`}
  aria-label={`${t('proxies.testNode')} · ${node.name}`}
  aria-busy={testing}
  disabled={testing}
  onclick={() => testNode(node.name)}
>
  {#if testing}
    <span class="spinner" aria-hidden="true"></span><span class="delay-pending">…</span>
  {:else}
    {#key revision}
      <span class:delay-result={revision > 0}>
        {#if minimal}<span class="dot {delayTone(node.delay)}"></span>{:else if node.delay != null}{formatDelay(
            node.delay,
          )}{:else}<Icon name="bolt" />{/if}
      </span>
    {/key}
  {/if}
</button>
