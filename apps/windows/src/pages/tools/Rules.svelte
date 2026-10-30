<script>
  import { invoke } from '@tauri-apps/api/core';
  import { app } from '../../lib/core.svelte.js';
  import { t } from '../../lib/i18n.js';
  import EmptyState from '../../lib/EmptyState.svelte';

  let { query = '' } = $props();
  let rules = $state(null);
  const LIMIT = 400;

  $effect(() => {
    app.status?.engine.state;
    invoke('rules').then((list) => (rules = list), () => (rules = []));
  });

  const shown = $derived.by(() => {
    const q = query.trim().toLowerCase();
    const list = rules ?? [];
    return q ? list.filter((r) => `${r.kind} ${r.payload} ${r.proxy}`.toLowerCase().includes(q)) : list;
  });
</script>

{#if rules && !rules.length}
  <EmptyState icon="rules" title={t('rules.empty')} detail={t('rules.emptyHint')} />
{:else if rules}
  <div class="list">
    {#each shown.slice(0, LIMIT) as rule, i (i)}
      <div class="row">
        <span class="tag">{rule.kind}</span>
        <span class="label"><span class="title selectable">{rule.payload || '—'}</span></span>
        <span class="trailing title">{rule.proxy}</span>
      </div>
    {/each}
  </div>
  {#if shown.length > LIMIT}<p class="note">{t('rules.more', { count: shown.length - LIMIT })}</p>{/if}
{/if}
