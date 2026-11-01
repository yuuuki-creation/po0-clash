<script>
  import { isTestingNode, testNode } from './core.svelte.js';
  import { delayTone, formatDelay, t } from './i18n.js';

  let { node, minimal = false } = $props();
  const testing = $derived(isTestingNode(node.name));
  const tone = $derived(delayTone(node.delay));
</script>

<button
  type="button"
  class="delay-btn {tone}"
  class:wait={testing}
  title={`${t('proxies.testNode')} · ${node.name}`}
  aria-label={`${t('proxies.testNode')} · ${node.name}`}
  aria-busy={testing}
  disabled={testing}
  onclick={() => testNode(node.name)}
>
  {#if minimal}<span class="dot small {tone}"></span>{:else}{formatDelay(node.delay) || '—'}{/if}
</button>
