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
  <EmptyState icon="rules" title={t('rules.empty')} />
{:else if rules}
  <section class="tbl auto">
    {#each shown.slice(0, LIMIT) as rule, i (i)}
      <div class="row t-rule">
        <span class="val clip">{rule.kind}</span>
        <span class="clip selectable" title={rule.payload}>{rule.payload || '—'}</span>
        <span class="val clip">{rule.proxy}</span>
      </div>
    {/each}
    {#if shown.length > LIMIT}<div class="empty-row">{t('rules.more', { count: shown.length - LIMIT })}</div>{/if}
  </section>
{/if}
