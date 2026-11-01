<script>
  import { act, app, notify } from '../lib/core.svelte.js';
  import { formatTime, t } from '../lib/i18n.js';
  import Dialog from '../lib/Dialog.svelte';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import { rowIn, rowOut } from '../lib/motion.svelte.js';
  import Page from '../lib/Page.svelte';
  import Switch from '../lib/Switch.svelte';

  let adding = $state(false);
  let removing = $state(null);
  let text = $state('');
  let name = $state('');

  const entries = $derived(app.whitelist.entries);
  const enabled = $derived(app.whitelist.enabled);

  const outcomeTone = { applied: 'on', notApplied: 'fair', disabled: '', rejected: 'bad', error: 'bad' };

  async function add(event) {
    event.preventDefault();
    const count = await act('wl:add', 'add_whitelist_entries', { text, name });
    if (count !== undefined) {
      text = '';
      name = '';
      adding = false;
      notify(t('whitelist.added', { count }));
    }
  }

  function remove() {
    act(`wl:remove:${removing.id}`, 'remove_whitelist_entry', { id: removing.id });
    removing = null;
  }
</script>

<Page title={t('page.whitelist')}>
  {#snippet actions()}
    <button type="button" class="btn" disabled={!entries.length || !enabled || app.busy['wl:now']} onclick={() => act('wl:now', 'whitelist_now')}
      >{t('whitelist.now')}</button
    >
    <button type="button" class="btn primary" onclick={() => (adding = true)}>{t('whitelist.add')}</button>
  {/snippet}

  <section class="group">
    <div class="row">
      <span class="grow">{t('whitelist.enabled')}</span>
      <Switch
        label={t('whitelist.enabled')}
        checked={enabled}
        disabled={app.busy['wl:enabled']}
        onchange={(enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })}
      />
    </div>
  </section>

  <section>
    <h2 class="section-title">{t('whitelist.entries')}</h2>
    {#if !entries.length}
      <EmptyState icon="whitelist" title={t('whitelist.empty')} />
    {:else}
      <div class="tbl auto">
        {#each entries as entry (entry.id)}
          <div class="row t-wl t-wl-row" in:rowIn={{ gap: 0 }} out:rowOut={{ gap: 0 }}>
            <span class="val">{entry.kind}</span>
            <span class="clip" title={entry.name}>{entry.name || entry.label}</span>
            <span class="val clip c-token" title={entry.label}>{entry.label}</span>
            <span class="status-line" title={entry.result ? formatTime(entry.result.at) : ''}>
              <span class="dot small {enabled && entry.result ? outcomeTone[entry.result.outcome] : ''}"></span>
              {!enabled ? t('outcome.disabled') : entry.result ? t(`outcome.${entry.result.outcome}`) : t('whitelist.pending')}
            </span>
            <span class="val selectable">{enabled ? (entry.result?.ip ?? '') : ''}</span>
            <button
              type="button"
              class="icon-btn"
              title={t('whitelist.remove')}
              aria-label={t('whitelist.remove')}
              disabled={app.busy[`wl:remove:${entry.id}`]}
              onclick={() => (removing = entry)}><Icon name="trash" /></button
            >
            {#if entry.result?.message}<span class="wl-message">{entry.result.message}</span>{/if}
          </div>
        {/each}
      </div>
    {/if}
  </section>
</Page>

{#if adding}
  <Dialog title={t('whitelist.addTitle')} onclose={() => (adding = false)}>
    <form id="add-entries" class="dialog-form" onsubmit={add}>
      <!-- svelte-ignore a11y_autofocus -->
      <textarea
        class="in"
        rows="4"
        bind:value={text}
        aria-label={t('whitelist.addTitle')}
        placeholder={t('whitelist.textPlaceholder')}
        spellcheck="false"
        autofocus
      ></textarea>
      <input class="in" bind:value={name} aria-label={t('whitelist.namePlaceholder')} placeholder={t('whitelist.namePlaceholder')} />
    </form>
    {#snippet actions()}
      <button type="submit" form="add-entries" class="btn primary" disabled={!text.trim() || app.busy['wl:add']}>{t('whitelist.add')}</button>
    {/snippet}
  </Dialog>
{/if}

{#if removing}
  <Dialog title={t('whitelist.confirmRemove', { name: removing.name || removing.label })} onclose={() => (removing = null)}>
    {#snippet actions()}
      <button type="button" class="btn primary" onclick={remove}>{t('whitelist.remove')}</button>
    {/snippet}
  </Dialog>
{/if}
