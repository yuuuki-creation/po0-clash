<script>
  import { act, app, notify } from '../lib/core.svelte.js';
  import { formatBytes, formatDate, formatTime, t } from '../lib/i18n.js';
  import ConfirmButton from '../lib/ConfirmButton.svelte';
  import Icon from '../lib/Icon.svelte';

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

<div class="section-title">{t('profiles.title')}</div>
<div class="group">
  {#each app.profiles as profile (profile.id)}
    <div class="row">
      <button
        type="button"
        class="check text-button"
        aria-label={t('profiles.use')}
        disabled={profile.selected || app.busy[`select:${profile.id}`]}
        onclick={() => act(`select:${profile.id}`, 'select_profile', { id: profile.id })}
      >
        {#if profile.selected}<Icon name="check" />{:else}<span class="dot"></span>{/if}
      </button>
      <div class="grow">
        <span class="title">{profile.kind === 'links' ? t('profiles.links') : profile.name}</span>
        {#if profile.usage}
          <div class="meter"><span style:width="{percent(profile.usage)}%"></span></div>
          <span class="sub">
            {t('profiles.used', {
              used: formatBytes(profile.usage.upload + profile.usage.download),
              total: formatBytes(profile.usage.total),
            })}{#if profile.usage.expire}
              · {t('profiles.expire', { date: formatDate(profile.usage.expire) })}{/if}
          </span>
        {/if}
        {#if profile.updatedAt}
          <span class="sub">{t('profiles.updated', { time: formatTime(profile.updatedAt) })}</span>
        {/if}
      </div>
      <div class="actions">
        {#if profile.kind === 'subscription'}
          <button
            type="button"
            class="text-button"
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
    </div>
  {/each}
  <form class="row" onsubmit={add}>
    <input type="url" bind:value={url} placeholder={t('profiles.urlPlaceholder')} spellcheck="false" />
    <button type="submit" class="pill" disabled={!url.trim() || app.busy.add}>{t('profiles.add')}</button>
  </form>
</div>
{#if !app.profiles.length}
  <div class="footnote">{t('profiles.empty')}</div>
{/if}

<div class="section-title">{t('profiles.import')}</div>
<div class="group">
  <div class="row stack">
    <textarea rows="4" bind:value={links} placeholder={t('profiles.importPlaceholder')} spellcheck="false"></textarea>
    <div class="actions">
      <button type="button" class="pill" disabled={!links.trim() || app.busy.import} onclick={importLinks}
        >{t('profiles.importButton')}</button
      >
    </div>
  </div>
</div>
