<script>
  import { act } from '../../lib/core.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Icon from '../../lib/Icon.svelte';
  import Page from '../../lib/Page.svelte';

  let { onback } = $props();
  let licenses = $state([]);
  let query = $state('');

  const needle = $derived(query.trim().toLowerCase());
  const shown = $derived(licenses.filter((l) => !needle || `${l.name} ${l.license}`.toLowerCase().includes(needle)));

  $effect(() => {
    act('licenses', 'licenses').then((list) => list && (licenses = list));
  });
</script>

<Page title={t('licenses.title')} subtitle={t('licenses.count', { count: licenses.length })} {onback} form>
  {#snippet actions()}
    <label class="search glass">
      <Icon name="search" />
      <input bind:value={query} aria-label={t('licenses.search')} placeholder={t('licenses.search')} spellcheck="false" />
    </label>
  {/snippet}

  <div class="list">
    {#each shown as item (`${item.name}@${item.version}`)}
      <button type="button" class="row tall" title={item.url} onclick={() => act('open', 'open_url', { url: item.url })}>
        <span class="label">
          <span>{item.name} <span class="sub">{item.version}</span></span>
          <span class="sub">{item.license}</span>
        </span>
        <span class="chevron"><Icon name="chevron" /></span>
      </button>
    {:else}
      {#if licenses.length}<div class="row"><span class="sub">{t('licenses.noMatch')}</span></div>{/if}
    {/each}
  </div>
</Page>
