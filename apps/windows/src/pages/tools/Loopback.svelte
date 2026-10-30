<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../../lib/core.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Icon from '../../lib/Icon.svelte';
  import Page from '../../lib/Page.svelte';
  import Switch from '../../lib/Switch.svelte';

  let { onback } = $props();
  let apps = $state(null);
  let query = $state('');

  const needle = $derived(query.trim().toLowerCase());
  const shown = $derived(
    (apps ?? []).filter((a) => !needle || a.displayName.toLowerCase().includes(needle) || a.name.toLowerCase().includes(needle)),
  );
  const exempted = $derived((apps ?? []).filter((a) => a.exempt).length);

  const load = () =>
    act('loopback:load', 'loopback_apps').then((list) => list && (apps = list));

  $effect(() => {
    load();
  });

  async function apply(exempt) {
    const sids = apps.filter(exempt).map((a) => a.sid);
    if ((await act('loopback', 'set_loopback', { sids })) !== undefined) await load();
  }
</script>

<Page
  title={t('tools.loopback')}
  subtitle={apps ? t('loopback.summary', { count: exempted, total: apps.length }) : t('page.tools')}
  {onback}
  form
>
  {#snippet actions()}
    <label class="search glass">
      <Icon name="search" />
      <input bind:value={query} aria-label={t('loopback.search')} placeholder={t('loopback.search')} spellcheck="false" />
    </label>
    <div class="tb-group glass">
      <button type="button" disabled={!apps?.length || app.busy.loopback} onclick={() => apply(() => true)}
        >{t('loopback.all')}</button
      >
      <button type="button" disabled={!exempted || app.busy.loopback} onclick={() => apply(() => false)}
        >{t('loopback.none')}</button
      >
    </div>
    <div class="tb-group glass">
      <button
        type="button"
        title={t('loopback.refresh')}
        aria-label={t('loopback.refresh')}
        disabled={app.busy['loopback:load']}
        onclick={load}><Icon name="refresh" /></button
      >
    </div>
  {/snippet}

  {#if apps}
    <div class="list">
      {#each shown as item (item.sid)}
        <div class="row tall">
          <div class="label">
            <span>{item.displayName}</span>
            {#if item.displayName !== item.name}<span class="sub">{item.name}</span>{/if}
          </div>
          <Switch
            label={item.displayName}
            checked={item.exempt}
            disabled={app.busy.loopback}
            onchange={(on) => apply((a) => (a.sid === item.sid ? on : a.exempt))}
          />
        </div>
      {:else}
        <div class="row"><span class="sub">{t(apps.length ? 'loopback.noMatch' : 'loopback.empty')}</span></div>
      {/each}
    </div>
    <p class="note">{t('loopback.hint')}</p>
  {/if}
</Page>
