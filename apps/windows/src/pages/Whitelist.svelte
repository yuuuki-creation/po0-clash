<script>
  import { flip } from 'svelte/animate';
  import { act, app, notify } from '../lib/core.svelte.js';
  import { formatTime, t } from '../lib/i18n.js';
  import Dialog from '../lib/Dialog.svelte';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import { motion, rise } from '../lib/motion.svelte.js';
  import Page from '../lib/Page.svelte';
  import Switch from '../lib/Switch.svelte';

  let adding = $state(false);
  let removing = $state(null);
  let text = $state('');
  let name = $state('');

  const entries = $derived(app.whitelist.entries);
  const applied = $derived(entries.filter((e) => e.result?.outcome === 'applied').length);

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

<Page
  title={t('page.whitelist')}
  subtitle={entries.length ? t('whitelist.summary', { applied, total: entries.length }) : ''}
  form
>
  {#snippet actions()}
    <div class="tb-group glass">
      <button
        type="button"
        title={t('whitelist.now')}
        aria-label={t('whitelist.now')}
        disabled={!entries.length || app.busy['wl:now']}
        onclick={() => act('wl:now', 'whitelist_now')}><Icon name="refresh" /></button
      >
    </div>
    <div class="tb-group glass">
      <button
        type="button"
        title={t('whitelist.addEllipsis')}
        aria-label={t('whitelist.addEllipsis')}
        onclick={() => (adding = true)}><Icon name="plus" /></button
      >
    </div>
  {/snippet}

  <section class="section">
    <div class="list">
      <div class="row tall">
        <div class="label">
          <span>{t('whitelist.enabled')}</span>
          <span class="sub">{t('whitelist.hint')}</span>
        </div>
        <Switch
          label={t('whitelist.enabled')}
          checked={app.whitelist.enabled}
          disabled={app.busy['wl:enabled']}
          onchange={(enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })}
        />
      </div>
    </div>
  </section>

  <section class="section">
    <h2 class="group-title">{t('whitelist.entries')}</h2>
    {#if !entries.length}
      <div class="list">
        <EmptyState icon="shield" title={t('whitelist.empty')} detail={t('whitelist.emptyHint')} />
      </div>
    {:else}
      <div class="list">
        {#each entries as entry (entry.id)}
          <div class="row top" animate:flip={{ duration: motion(260) }} transition:rise>
            <span class="tag mono">{entry.kind}</span>
            <div class="grow">
              <span class="title">
                {#if entry.name}<span class="strong">{entry.name}</span>{/if}
                <span class="sub mono">{entry.label}</span>
              </span>
              <span class="result {entry.result?.outcome ?? ''}">
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
              </span>
              {#if entry.result?.message}<span class="sub selectable">{entry.result.message}</span>{/if}
            </div>
            <button
              type="button"
              class="icon-button"
              title={t('whitelist.remove')}
              aria-label={t('whitelist.remove')}
              disabled={app.busy[`wl:remove:${entry.id}`]}
              onclick={() => (removing = entry)}><Icon name="trash" /></button
            >
          </div>
        {/each}
      </div>
    {/if}
  </section>
</Page>

{#if adding}
  <Dialog title={t('whitelist.addTitle')} onclose={() => (adding = false)}>
    <form id="add-entries" class="stack" onsubmit={add}>
      <!-- svelte-ignore a11y_autofocus -->
      <textarea
        rows="5"
        bind:value={text}
        aria-label={t('whitelist.addTitle')}
        placeholder={t('whitelist.textPlaceholder')}
        spellcheck="false"
        autofocus
      ></textarea>
      <input bind:value={name} aria-label={t('whitelist.namePlaceholder')} placeholder={t('whitelist.namePlaceholder')} />
    </form>
    {#snippet actions()}
      <button type="submit" form="add-entries" class="pill filled" disabled={!text.trim() || app.busy['wl:add']}
        >{t('whitelist.add')}</button
      >
    {/snippet}
  </Dialog>
{/if}

{#if removing}
  <Dialog
    title={t('whitelist.confirmRemove', { name: removing.name || removing.label })}
    onclose={() => (removing = null)}
  >
    {#snippet actions()}
      <button type="button" class="pill destructive" onclick={remove}>{t('whitelist.remove')}</button>
    {/snippet}
  </Dialog>
{/if}
