<script>
  import { act } from '../../lib/core.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Icon from '../../lib/Icon.svelte';
  import Page from '../../lib/Page.svelte';

  let { crumbs } = $props();
  let licenses = $state([]);
  let query = $state('');

  const needle = $derived(query.trim().toLowerCase());
  const shown = $derived(licenses.filter((l) => !needle || `${l.name} ${l.license}`.toLowerCase().includes(needle)));

  $effect(() => {
    act('licenses', 'licenses').then((list) => list && (licenses = list));
  });
</script>

<Page title={t('licenses.title')} {crumbs}>
  {#snippet actions()}
    <label class="search">
      <Icon name="search" />
      <input bind:value={query} aria-label={t('licenses.search')} placeholder={t('licenses.search')} spellcheck="false" />
    </label>
  {/snippet}

  <div class="group">
    {#each shown as item (`${item.name}@${item.version}`)}
      <button type="button" class="row" title={item.url} onclick={() => act('open', 'open_url', { url: item.url })}>
        <span class="grow clip">{item.name}</span>
        <span class="val">{item.version}</span>
        <span class="val">{item.license}</span>
        <Icon name="chevron" class="chev" />
      </button>
    {:else}
      {#if licenses.length}<div class="row"><span class="val">{t('licenses.noMatch')}</span></div>{/if}
    {/each}
  </div>
</Page>
