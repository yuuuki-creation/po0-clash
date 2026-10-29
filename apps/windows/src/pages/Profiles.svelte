<script>
  import { act, app, notify } from '../lib/core.svelte.js';
  import { formatBytes, formatDate, formatTime, t } from '../lib/i18n.js';
  import ConfirmButton from '../lib/ConfirmButton.svelte';

  let url = $state('');
  let links = $state('');

  async function add(event) {
    event.preventDefault();
    if (await act('add', 'add_subscription', { url })) url = '';
  }

  async function importLinks() {
    const result = await act('import', 'import_links', { text: links });
    if (result) {
      links = '';
      notify(t('profiles.imported', { count: result.added }));
    }
  }

  function percent(usage) {
    if (!usage.total) return 0;
    return Math.min(100, ((usage.upload + usage.download) / usage.total) * 100);
  }
</script>

<form class="card inline-form" onsubmit={add}>
  <input type="url" bind:value={url} placeholder={t('profiles.urlPlaceholder')} spellcheck="false" />
  <button type="submit" class="accent" disabled={!url.trim() || app.busy.add}>{t('profiles.add')}</button>
</form>

{#if !app.profiles.length}
  <p class="empty">{t('profiles.empty')}</p>
{/if}

{#each app.profiles as profile (profile.id)}
  <section class="card profile" class:selected={profile.selected}>
    <div class="profile-head">
      <span class="title">{profile.kind === 'links' ? t('profiles.links') : profile.name}</span>
      {#if profile.selected}<span class="badge">{t('profiles.inUse')}</span>{/if}
    </div>
    {#if profile.usage}
      <div class="meter"><span style:width="{percent(profile.usage)}%"></span></div>
      <div class="sub">
        {t('profiles.used', {
          used: formatBytes(profile.usage.upload + profile.usage.download),
          total: formatBytes(profile.usage.total),
        })}
        {#if profile.usage.expire}· {t('profiles.expire', { date: formatDate(profile.usage.expire) })}{/if}
      </div>
    {/if}
    {#if profile.updatedAt}
      <div class="sub">{t('profiles.updated', { time: formatTime(profile.updatedAt) })}</div>
    {/if}
    <div class="actions">
      {#if !profile.selected}
        <button
          type="button"
          class="accent"
          disabled={app.busy[`select:${profile.id}`]}
          onclick={() => act(`select:${profile.id}`, 'select_profile', { id: profile.id })}>{t('profiles.use')}</button
        >
      {/if}
      {#if profile.kind === 'subscription'}
        <button
          type="button"
          disabled={app.busy[`update:${profile.id}`]}
          onclick={() => act(`update:${profile.id}`, 'update_profile', { id: profile.id })}>{t('profiles.update')}</button
        >
      {/if}
      <ConfirmButton
        label={t('profiles.delete')}
        confirmLabel={t('profiles.confirmDelete')}
        disabled={app.busy[`remove:${profile.id}`]}
        onconfirm={() => act(`remove:${profile.id}`, 'remove_profile', { id: profile.id })}
      />
    </div>
  </section>
{/each}

<section class="card stack">
  <div class="label">{t('profiles.import')}</div>
  <textarea rows="4" bind:value={links} placeholder={t('profiles.importPlaceholder')} spellcheck="false"></textarea>
  <div class="actions">
    <button type="button" disabled={!links.trim() || app.busy.import} onclick={importLinks}>{t('profiles.importButton')}</button>
  </div>
</section>
