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
  <EmptyState icon="providers" title={t('prov.empty')} />
{/if}
{#each sections as section (section.kind)}
  <section>
    <h2 class="section-title">{t(`prov.${section.kind}`)}</h2>
    <div class="group">
      {#each section.items as provider (provider.name)}
        {@const busy = app.busy[`provider:${provider.kind}:${provider.name}`]}
        {@const usage = provider.usage}
        <div class="row">
          <span class="clip provider-name">{provider.name}</span>
          <span class="val clip grow">
            {[provider.vehicle, provider.behavior, t('prov.count', { count: provider.count })].filter(Boolean).join(' · ')}{provider.updatedAt
              ? ` · ${formatAgo(provider.updatedAt)}`
              : ''}
          </span>
          {#if usage?.total}
            <span class="usage provider-usage">
              <span class="bar-track"
                ><span class="bar-fill" style:width="{Math.min(100, ((usage.upload + usage.download) / usage.total) * 100)}%"></span></span
              >
              <span class="val">{formatBytes(usage.upload + usage.download)} / {formatBytes(usage.total)}</span>
            </span>
          {/if}
          {#if provider.vehicle === 'HTTP'}
            <button
              type="button"
              class="icon-btn"
              title={t('prov.update')}
              aria-label={t('prov.update')}
              disabled={busy}
              onclick={() => update(provider)}
            >
              <Icon name="refresh" class={busy ? 'spin' : ''} />
            </button>
          {/if}
        </div>
      {/each}
    </div>
  </section>
{/each}
