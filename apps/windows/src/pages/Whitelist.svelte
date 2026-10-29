<script>
  import { act, app, notify } from '../lib/core.svelte.js';
  import { formatTime, t } from '../lib/i18n.js';
  import ConfirmButton from '../lib/ConfirmButton.svelte';
  import Switch from '../lib/Switch.svelte';

  let text = $state('');
  let name = $state('');

  async function add(event) {
    event.preventDefault();
    const count = await act('wl:add', 'add_whitelist_entries', { text, name });
    if (count !== undefined) {
      text = '';
      name = '';
      notify(t('whitelist.added', { count }));
    }
  }
</script>

<div class="group">
  <div class="row">
    <span class="grow">{t('whitelist.enabled')}</span>
    <Switch
      label={t('whitelist.enabled')}
      checked={app.whitelist.enabled}
      disabled={app.busy['wl:enabled']}
      onchange={(enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })}
    />
  </div>
</div>
<div class="footnote">{t('whitelist.hint')}</div>

<div class="section-title">
  <span>{t('whitelist.entries')}</span>
  {#if app.whitelist.entries.length}
    <button
      type="button"
      class="text-button"
      disabled={app.busy['wl:now']}
      onclick={() => act('wl:now', 'whitelist_now')}>{t('whitelist.now')}</button
    >
  {/if}
</div>
<div class="group">
  {#each app.whitelist.entries as entry (entry.id)}
    <div class="row">
      <span class="tag">{entry.kind}</span>
      <div class="grow">
        <span class="title">{entry.name || entry.label}</span>
        {#if entry.name}<span class="sub mono">{entry.label}</span>{/if}
        <div class="result {entry.result?.outcome ?? ''}">
          <span class="dot"></span>
          {#if entry.result}
            <span class="title"
              >{t(`outcome.${entry.result.outcome}`)}{entry.result.ip ? ` · ${entry.result.ip}` : ''} · {formatTime(
                entry.result.at,
              )}</span
            >
          {:else}
            <span>{t('whitelist.pending')}</span>
          {/if}
        </div>
        {#if entry.result?.message}<span class="sub">{entry.result.message}</span>{/if}
      </div>
      <ConfirmButton
        label={t('whitelist.remove')}
        confirmLabel={t('profiles.confirmDelete')}
        disabled={app.busy[`wl:remove:${entry.id}`]}
        onconfirm={() => act(`wl:remove:${entry.id}`, 'remove_whitelist_entry', { id: entry.id })}
      />
    </div>
  {/each}
  <form class="row stack" onsubmit={add}>
    <textarea rows="3" bind:value={text} placeholder={t('whitelist.textPlaceholder')} spellcheck="false"></textarea>
    <div class="actions">
      <input bind:value={name} placeholder={t('whitelist.namePlaceholder')} />
      <button type="submit" class="pill" disabled={!text.trim() || app.busy['wl:add']}>{t('whitelist.add')}</button>
    </div>
  </form>
</div>
