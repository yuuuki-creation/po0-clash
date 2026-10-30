<script>
  import { flip } from 'svelte/animate';
  import { act, app, notify } from '../lib/core.svelte.js';
  import { formatTime, t } from '../lib/i18n.js';
  import Dialog from '../lib/Dialog.svelte';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import { motion, navigate, rise } from '../lib/motion.svelte.js';
  import Page from '../lib/Page.svelte';
  import Switch from '../lib/Switch.svelte';
  import UsageBar from '../lib/UsageBar.svelte';
  import Override from './profiles/Override.svelte';
  import ShareNodes from './profiles/ShareNodes.svelte';

  let dialog = $state(null);
  let removing = $state(null);
  let editing = $state(null);
  let preview = $state(null);
  let url = $state('');
  let links = $state('');
  let picker = $state();
  let dragged = $state(null);
  let target = $state(null);

  const title = (profile) => (profile.kind === 'links' ? t('profiles.links') : profile.name);
  const subject = $derived.by(() => {
    const profile = app.tool && app.profiles.find((p) => p.id === app.tool.id);
    return profile && { ...profile, title: title(profile) };
  });
  const open = (view, profile) => navigate('profiles', { view, id: profile.id }, 'forward');
  const back = () => navigate('profiles', null, 'back');

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

  async function importFile(event) {
    const file = event.target.files[0];
    event.target.value = '';
    if (!file) return;
    const profile = await act('importFile', 'import_file', { name: file.name, content: await file.text() });
    if (profile) notify(t('profiles.importedFile', { name: profile.name }));
  }

  function remove() {
    act(`remove:${removing.id}`, 'remove_profile', { id: removing.id });
    removing = null;
  }

  function edit(profile) {
    editing = {
      id: profile.id,
      kind: profile.kind,
      title: title(profile),
      name: profile.name,
      url: profile.url ?? '',
      autoUpdate: profile.autoUpdate,
      updateHours: profile.updateHours,
    };
  }

  async function save(event) {
    event.preventDefault();
    const { id, kind, name, url: link, autoUpdate, updateHours } = editing;
    if (kind === 'links') {
      editing = null;
      return;
    }
    const edit = { name, url: kind === 'subscription' ? link : null, autoUpdate, updateHours: Number(updateHours) };
    if (await act('edit', 'edit_profile', { id, edit })) editing = null;
  }

  async function showPreview() {
    const config = await act('preview', 'preview_config', { id: editing.id });
    if (config !== undefined) preview = { title: editing.title, config };
  }

  async function exportProfile() {
    const path = await act('export', 'export_profile', { id: editing.id, name: editing.title });
    if (path) notify(t('profiles.exported', { path }));
  }

  function drop(over) {
    const from = dragged;
    dragged = target = null;
    if (!from || from === over) return;
    const ids = app.profiles.map((p) => p.id).filter((id) => id !== from);
    ids.splice(ids.indexOf(over), 0, from);
    app.profiles = ids.map((id) => app.profiles.find((p) => p.id === id));
    act('reorder', 'reorder_profiles', { ids });
  }
</script>

{#if subject && app.tool.view === 'override'}
  <Override profile={subject} onback={back} />
{:else if subject && app.tool.view === 'nodes'}
  <ShareNodes profile={subject} onback={back} />
{:else}
  <Page title={t('page.profiles')} subtitle={app.profiles.length ? t('profiles.count', { count: app.profiles.length }) : ''} fill={!app.profiles.length} form={!!app.profiles.length}>
    {#snippet actions()}
      <div class="tb-group glass">
        <button
          type="button"
          title={t('profiles.importFile')}
          aria-label={t('profiles.importFile')}
          disabled={app.busy.importFile}
          onclick={() => picker.click()}><Icon name="doc" /></button
        >
        <button
          type="button"
          title={t('profiles.importEllipsis')}
          aria-label={t('profiles.importEllipsis')}
          onclick={() => (dialog = 'links')}><Icon name="link" /></button
        >
        <button
          type="button"
          title={t('profiles.addEllipsis')}
          aria-label={t('profiles.addEllipsis')}
          onclick={() => (dialog = 'url')}><Icon name="plus" /></button
        >
      </div>
    {/snippet}

    <input bind:this={picker} type="file" accept=".yaml,.yml,.txt,.conf" hidden onchange={importFile} />

    {#if !app.profiles.length}
      <EmptyState icon="stack" title={t('profiles.empty')} detail={t('profiles.emptyHint')} />
    {:else}
      <section class="section">
        <h2 class="group-title">{t('profiles.section')}</h2>
        <div class="list">
          {#each app.profiles as profile (profile.id)}
            <div
              animate:flip={{ duration: motion(260) }}
              transition:rise
              class="row top"
              class:dragging={dragged === profile.id}
              class:drop-target={target === profile.id && dragged !== profile.id}
              role="listitem"
              draggable={app.profiles.length > 1}
              ondragstart={(event) => {
                dragged = profile.id;
                event.dataTransfer.effectAllowed = 'move';
              }}
              ondragover={(event) => {
                if (!dragged) return;
                event.preventDefault();
                target = profile.id;
              }}
              ondrop={(event) => {
                event.preventDefault();
                drop(profile.id);
              }}
              ondragend={() => (dragged = target = null)}
            >
              {#if app.profiles.length > 1}
                <span class="grip" title={t('profiles.reorder')}><Icon name="grip" /></span>
              {/if}
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
              <div class="grow stacked">
                <span class="title strong">{title(profile)}</span>
                {#if profile.usage}<UsageBar usage={profile.usage} />{/if}
                <span class="sub">
                  {#if profile.updatedAt}{t('profiles.updated', { time: formatTime(profile.updatedAt) })}{/if}
                  {#if profile.kind === 'subscription' && profile.autoUpdate}
                    · {t('profiles.autoUpdateEvery', { hours: profile.updateHours })}{/if}
                </span>
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
              {#if profile.kind === 'links'}
                <button
                  type="button"
                  class="icon-button"
                  title={t('nodes.title')}
                  aria-label={t('nodes.title')}
                  onclick={() => open('nodes', profile)}><Icon name="grid" /></button
                >
              {/if}
              <button
                type="button"
                class="icon-button"
                title={t('override.title')}
                aria-label={t('override.title')}
                onclick={() => open('override', profile)}><Icon name="sliders" /></button
              >
              <button
                type="button"
                class="icon-button"
                title={t('profiles.edit')}
                aria-label={t('profiles.edit')}
                onclick={() => edit(profile)}><Icon name="pencil" /></button
              >
              <button
                type="button"
                class="icon-button"
                title={t('profiles.delete')}
                aria-label={t('profiles.delete')}
                disabled={app.busy[`remove:${profile.id}`]}
                onclick={() => (removing = profile)}><Icon name="trash" /></button
              >
            </div>
          {/each}
        </div>
      </section>
    {/if}
  </Page>
{/if}

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

{#if editing && !preview}
  <Dialog title={t('profiles.editTitle')} onclose={() => (editing = null)}>
    <form id="edit-profile" class="stack" onsubmit={save}>
      {#if editing.kind !== 'links'}
        <label class="field">
          <span class="sub">{t('profiles.name')}</span>
          <input bind:value={editing.name} spellcheck="false" />
        </label>
      {/if}
      {#if editing.kind === 'subscription'}
        <label class="field">
          <span class="sub">{t('profiles.url')}</span>
          <input type="url" bind:value={editing.url} spellcheck="false" />
        </label>
        <div class="split">
          <span class="grow">{t('profiles.autoUpdate')}</span>
          <label class="hours">
            <span class="sub">{t('profiles.updateHours')}</span>
            <input
              type="number"
              min="1"
              max="720"
              bind:value={editing.updateHours}
              disabled={!editing.autoUpdate}
              aria-label={t('profiles.updateHours')}
            />
          </label>
          <Switch
            label={t('profiles.autoUpdate')}
            checked={editing.autoUpdate}
            onchange={(on) => (editing.autoUpdate = on)}
          />
        </div>
      {/if}
      <div class="split">
        <button type="button" class="pill" disabled={app.busy.preview} onclick={showPreview}
          >{t('profiles.preview')}</button
        >
        <button type="button" class="pill" disabled={app.busy.export} onclick={exportProfile}
          >{t('profiles.export')}</button
        >
      </div>
    </form>
    {#snippet actions()}
      <button
        type="submit"
        form="edit-profile"
        class="pill filled"
        disabled={(editing.kind !== 'links' && !editing.name.trim()) || app.busy.edit}>{t('profiles.save')}</button
      >
    {/snippet}
  </Dialog>
{/if}

{#if preview}
  <Dialog title={t('profiles.previewTitle', { name: preview.title })} wide onclose={() => (preview = null)}>
    <pre class="preview selectable">{preview.config}</pre>
  </Dialog>
{/if}

{#if removing}
  <Dialog title={t('profiles.confirmDelete', { name: title(removing) })} onclose={() => (removing = null)}>
    {#snippet actions()}
      <button type="button" class="pill destructive" onclick={remove}>{t('profiles.delete')}</button>
    {/snippet}
  </Dialog>
{/if}
