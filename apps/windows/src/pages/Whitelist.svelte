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

<section class="card row">
  <div class="grow-text">
    <span class="title">{t('whitelist.enabled')}</span>
    <span class="sub">{t('whitelist.hint')}</span>
  </div>
  <Switch
    label={t('whitelist.enabled')}
    checked={app.whitelist.enabled}
    disabled={app.busy['wl:enabled']}
    onchange={(enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })}
  />
</section>

{#if app.whitelist.entries.length}
  <div class="toolbar">
    <button type="button" disabled={app.busy['wl:now']} onclick={() => act('wl:now', 'whitelist_now')}
      >{t('whitelist.now')}</button
    >
  </div>
{:else}
  <p class="empty">{t('whitelist.empty')}</p>
{/if}

{#each app.whitelist.entries as entry (entry.id)}
  <section class="card entry">
    <div class="entry-head">
      <span class="tag">{entry.kind}</span>
      <span class="grow-text">
        <span class="title">{entry.name || entry.label}</span>
        {#if entry.name}<span class="sub mono">{entry.label}</span>{/if}
      </span>
      <ConfirmButton
        label={t('whitelist.remove')}
        confirmLabel={t('profiles.confirmDelete')}
        disabled={app.busy[`wl:remove:${entry.id}`]}
        onconfirm={() => act(`wl:remove:${entry.id}`, 'remove_whitelist_entry', { id: entry.id })}
      />
    </div>
    {#if entry.result}
      <div class="result {entry.result.outcome}">
        <span class="dot" aria-hidden="true"></span>
        <span>
          {t(`outcome.${entry.result.outcome}`)}{entry.result.ip ? ` · ${entry.result.ip}` : ''} · {formatTime(
            entry.result.at,
          )}
        </span>
      </div>
      {#if entry.result.message}<div class="sub">{entry.result.message}</div>{/if}
    {:else}
      <div class="result"><span class="dot" aria-hidden="true"></span><span>{t('whitelist.pending')}</span></div>
    {/if}
  </section>
{/each}

<form class="card stack" onsubmit={add}>
  <textarea rows="3" bind:value={text} placeholder={t('whitelist.textPlaceholder')} spellcheck="false"></textarea>
  <div class="inline-form">
    <input bind:value={name} placeholder={t('whitelist.namePlaceholder')} />
    <button type="submit" class="accent" disabled={!text.trim() || app.busy['wl:add']}>{t('whitelist.add')}</button>
  </div>
</form>
