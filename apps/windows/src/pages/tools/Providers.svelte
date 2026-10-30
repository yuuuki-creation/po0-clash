<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app } from '../../lib/core.svelte.js';
  import { formatAgo, formatBytes, t } from '../../lib/i18n.js';
  import EmptyState from '../../lib/EmptyState.svelte';
  import Icon from '../../lib/Icon.svelte';

  let providers = $state(null);
  const load = () => invoke('providers').then((list) => (providers = list), () => (providers = []));
  $effect(() => {
    app.status?.engine.state;
    load();
  });

  async function update(provider) {
    await act(`provider:${provider.kind}:${provider.name}`, 'update_provider', { kind: provider.kind, name: provider.name });
    await load();
  }

  const sections = $derived(
    ['proxy', 'rule']
      .map((kind) => ({ kind, items: (providers ?? []).filter((p) => p.kind === kind) }))
      .filter((section) => section.items.length),
  );
</script>

{#if providers && !sections.length}
  <EmptyState icon="providers" title={t('prov.empty')} detail={t('prov.emptyHint')} />
{/if}
{#each sections as section (section.kind)}
  <h2 class="group-title">{t(`prov.${section.kind}`)}</h2>
  <div class="list">
    {#each section.items as provider (provider.name)}
      {@const busy = app.busy[`provider:${provider.kind}:${provider.name}`]}
      {@const usage = provider.usage}
      <div class="row top">
        <div class="label">
          <span class="strong">{provider.name}</span>
          <span class="sub">
            {[provider.vehicle, provider.behavior, t('prov.count', { count: provider.count })].filter(Boolean).join(' · ')}{provider.updatedAt
              ? ` · ${formatAgo(provider.updatedAt)}`
              : ''}
          </span>
          {#if usage?.total}
            <div class="bar" style:margin-top="4px">
              <span style:width="{Math.min(100, ((usage.upload + usage.download) / usage.total) * 100)}%"></span>
            </div>
            <span class="sub mono">{formatBytes(usage.upload + usage.download)} / {formatBytes(usage.total)}</span>
          {/if}
        </div>
        {#if provider.vehicle === 'HTTP'}
          <button
            type="button"
            class="round"
            title={t('prov.update')}
            aria-label={t('prov.update')}
            disabled={busy}
            onclick={() => update(provider)}
          >
            {#if busy}<span class="spinner"></span>{:else}<Icon name="refresh" />{/if}
          </button>
        {/if}
      </div>
    {/each}
  </div>
{/each}
