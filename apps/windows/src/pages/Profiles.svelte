<script>
  import { act, app, notify } from '../lib/core.svelte.js';
  import { formatTime, t } from '../lib/i18n.js';
  import Dialog from '../lib/Dialog.svelte';
  import Icon from '../lib/Icon.svelte';
  import Page from '../lib/Page.svelte';
  import UsageBar from '../lib/UsageBar.svelte';

  let dialog = $state(null);
  let removing = $state(null);
  let url = $state('');
  let links = $state('');

  const title = (profile) => (profile.kind === 'links' ? t('profiles.links') : profile.name);

  async function add(event) {
    event.preventDefault();
    if (await act('add', 'add_subscription', { url })) {
      url = '';
      dialog = null;
    }
  }

  async function importLinks(event) {
    event.preventDefault();
    const result = await act('import', 'import_links', { text: links });
    if (result) {
      links = '';
      dialog = null;
      notify(t('profiles.imported', { count: result.added }));
    }
  }

  function remove() {
    act(`remove:${removing.id}`, 'remove_profile', { id: removing.id });
    removing = null;
  }
</script>

<Page id="profiles">
  {#snippet actions()}
    <button type="button" onclick={() => (dialog = 'links')}><Icon name="link" />{t('profiles.importEllipsis')}</button>
    <button type="button" onclick={() => (dialog = 'url')}><Icon name="plus" />{t('profiles.addEllipsis')}</button>
  {/snippet}

  {#if !app.profiles.length}
    <div class="card empty">
      <span class="strong">{t('profiles.empty')}</span>
      <span class="sub">{t('profiles.emptyHint')}</span>
    </div>
  {/if}
  {#each app.profiles as profile (profile.id)}
    <section class="card profile" class:selected={profile.selected}>
      <button
        type="button"
        class="radio"
        class:on={profile.selected}
        title={t('profiles.use')}
        aria-label={t('profiles.use')}
        aria-pressed={profile.selected}
        disabled={app.busy[`select:${profile.id}`]}
        onclick={() => !profile.selected && act(`select:${profile.id}`, 'select_profile', { id: profile.id })}
        >{#if profile.selected}<Icon name="check" />{/if}</button
      >
      <div class="grow">
        <span class="title strong">{title(profile)}</span>
        {#if profile.usage}<UsageBar usage={profile.usage} />{/if}
        {#if profile.updatedAt}
          <span class="sub">{t('profiles.updated', { time: formatTime(profile.updatedAt) })}</span>
        {/if}
      </div>
      {#if profile.kind === 'subscription'}
        <button
          type="button"
          class="icon-button"
          title={t('profiles.update')}
          aria-label={t('profiles.update')}
          disabled={app.busy[`update:${profile.id}`]}
          onclick={() => act(`update:${profile.id}`, 'update_profile', { id: profile.id })}
        >
          {#if app.busy[`update:${profile.id}`]}<span class="spinner"></span>{:else}<Icon name="refresh" />{/if}
        </button>
      {/if}
      <button
        type="button"
        class="icon-button"
        title={t('profiles.delete')}
        aria-label={t('profiles.delete')}
        disabled={app.busy[`remove:${profile.id}`]}
        onclick={() => (removing = profile)}><Icon name="trash" /></button
      >
    </section>
  {/each}
</Page>

{#if dialog === 'url'}
  <Dialog title={t('profiles.add')} onclose={() => (dialog = null)}>
    <form id="add-url" onsubmit={add}>
      <!-- svelte-ignore a11y_autofocus -->
      <input
        type="url"
        bind:value={url}
        aria-label={t('profiles.url')}
        placeholder={t('profiles.urlPlaceholder')}
        spellcheck="false"
        autofocus
      />
    </form>
    {#snippet actions()}
      <button type="submit" form="add-url" class="pill filled" disabled={!url.trim() || app.busy.add}>
        {#if app.busy.add}<span class="spinner"></span>{/if}{t('profiles.add')}
      </button>
    {/snippet}
  </Dialog>
{:else if dialog === 'links'}
  <Dialog title={t('profiles.import')} onclose={() => (dialog = null)}>
    <form id="import-links" onsubmit={importLinks}>
      <p class="sub">{t('profiles.importHint')}</p>
      <!-- svelte-ignore a11y_autofocus -->
      <textarea rows="6" bind:value={links} aria-label={t('profiles.import')} spellcheck="false" autofocus></textarea>
    </form>
    {#snippet actions()}
      <button type="submit" form="import-links" class="pill filled" disabled={!links.trim() || app.busy.import}
        >{t('profiles.importButton')}</button
      >
    {/snippet}
  </Dialog>
{/if}

{#if removing}
  <Dialog title={t('profiles.confirmDelete', { name: title(removing) })} onclose={() => (removing = null)}>
    {#snippet actions()}
      <button type="button" class="pill destructive" onclick={remove}>{t('profiles.delete')}</button>
    {/snippet}
  </Dialog>
{/if}
