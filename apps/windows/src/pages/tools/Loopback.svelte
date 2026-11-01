<script>
  import { act, app } from '../../lib/core.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Icon from '../../lib/Icon.svelte';
  import Page from '../../lib/Page.svelte';
  import Switch from '../../lib/Switch.svelte';

  let { crumbs } = $props();
  let apps = $state(null);
  let query = $state('');

  const needle = $derived(query.trim().toLowerCase());
  const shown = $derived(
    (apps ?? []).filter((a) => !needle || a.displayName.toLowerCase().includes(needle) || a.name.toLowerCase().includes(needle)),
  );
  const exempted = $derived((apps ?? []).filter((a) => a.exempt).length);

  const load = () => act('loopback:load', 'loopback_apps').then((list) => list && (apps = list));

  $effect(() => {
    load();
  });

  async function apply(exempt) {
    const sids = apps.filter(exempt).map((a) => a.sid);
    if ((await act('loopback', 'set_loopback', { sids })) !== undefined) await load();
  }
</script>

<Page title={t('tools.loopback')} {crumbs}>
  {#snippet actions()}
    <label class="search">
      <Icon name="search" />
      <input bind:value={query} aria-label={t('loopback.search')} placeholder={t('loopback.search')} spellcheck="false" />
    </label>
    <button type="button" class="btn" disabled={!apps?.length || app.busy.loopback} onclick={() => apply(() => true)}>{t('loopback.all')}</button>
    <button type="button" class="btn" disabled={!exempted || app.busy.loopback} onclick={() => apply(() => false)}>{t('loopback.none')}</button>
    <button
      type="button"
      class="icon-btn"
      title={t('loopback.refresh')}
      aria-label={t('loopback.refresh')}
      disabled={app.busy['loopback:load']}
      onclick={load}><Icon name="refresh" class={app.busy['loopback:load'] ? 'spin' : ''} /></button
    >
  {/snippet}

  {#if apps}
    <div class="group">
      {#each shown as item (item.sid)}
        <div class="row">
          <span class="grow clip" title={item.name}>{item.displayName}</span>
          <Switch
            label={item.displayName}
            checked={item.exempt}
            disabled={app.busy.loopback}
            onchange={(on) => apply((a) => (a.sid === item.sid ? on : a.exempt))}
          />
        </div>
      {:else}
        <div class="row"><span class="val">{t(apps.length ? 'loopback.noMatch' : 'loopback.empty')}</span></div>
      {/each}
    </div>
  {/if}
</Page>
