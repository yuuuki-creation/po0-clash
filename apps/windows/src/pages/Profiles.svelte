<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../lib/core.svelte.js';
  import { formatDate, formatTime, formatUsage, t } from '../lib/i18n.js';
  import Dialog from '../lib/Dialog.svelte';
  import EmptyState from '../lib/EmptyState.svelte';
  import Icon from '../lib/Icon.svelte';
  import Menu from '../lib/Menu.svelte';
  import { navigate, rowIn, rowOut } from '../lib/motion.svelte.js';
  import Page from '../lib/Page.svelte';
  import Switch from '../lib/Switch.svelte';
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
  let nodeCounts = $state({});

  const title = (profile) => (profile.kind === 'links' ? t('profiles.links') : profile.name);
  const subject = $derived.by(() => {
    const profile = app.tool && app.profiles.find((p) => p.id === app.tool.id);
    return profile && { ...profile, title: title(profile) };
  });
  const open = (view, profile) => navigate('profiles', { view, id: profile.id }, 'drill');
  const back = () => navigate('profiles', null, 'back');
  const subscriptions = $derived(app.profiles.filter((p) => p.kind === 'subscription'));
  const updating = $derived(subscriptions.some((p) => app.busy[`update:${p.id}`]));
  const update = (profile) => act(`update:${profile.id}`, 'update_profile', { id: profile.id });

  $effect(() => {
    for (const { id, kind } of app.profiles) {
      if (kind === 'links') invoke('share_nodes', { id }).then((nodes) => (nodeCounts[id] = nodes.length), () => {});
    }
  });

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
      name: profile.name,
      url: profile.url ?? '',
      autoUpdate: profile.autoUpdate,
      updateHours: profile.updateHours,
    };
  }

  async function save(event) {
    event.preventDefault();
    const { id, kind, name, url: link, autoUpdate, updateHours } = editing;
    const edit = { name, url: kind === 'subscription' ? link : null, autoUpdate, updateHours: Number(updateHours) };
    if (await act('edit', 'edit_profile', { id, edit })) editing = null;
  }

  async function showPreview(profile) {
    const config = await act('preview', 'preview_config', { id: profile.id });
    if (config !== undefined) preview = { title: title(profile), config };
  }

  async function exportProfile(profile) {
    const path = await act('export', 'export_profile', { id: profile.id, name: title(profile) });
    if (path) notify(t('profiles.exported', { path }));
  }

  const addOptions = $derived([
    { value: 'url', label: t('profiles.addEllipsis') },
    { value: 'links', label: t('profiles.importEllipsis') },
    { value: 'file', label: t('profiles.importFile'), disabled: app.busy.importFile },
  ]);

  function addChosen(kind) {
    if (kind === 'file') picker.click();
    else dialog = kind;
  }

  const moreOptions = (profile) => [
    ...(profile.kind === 'links' ? [] : [{ value: 'edit', label: t('profiles.edit') }]),
    { value: 'override', label: t('override.title') },
    ...(profile.kind === 'links' ? [{ value: 'nodes', label: t('nodes.title') }] : []),
    { value: 'preview', label: t('profiles.preview'), disabled: app.busy.preview },
    { value: 'export', label: t('profiles.export'), disabled: app.busy.export },
    { value: 'remove', label: t('profiles.delete'), danger: true, disabled: app.busy[`remove:${profile.id}`] },
  ];

  const moreActions = {
    edit,
    override: (profile) => open('override', profile),
    nodes: (profile) => open('nodes', profile),
    preview: showPreview,
    export: exportProfile,
    remove: (profile) => (removing = profile),
  };

  function drop(over) {
    const from = dragged;
    dragged = target = null;
    if (!from || from === over) return;
    const ids = app.profiles.map((p) => p.id).filter((id) => id !== from);
    ids.splice(ids.indexOf(over), 0, from);
    app.profiles = ids.map((id) => app.profiles.find((p) => p.id === id));
    act('reorder', 'reorder_profiles', { ids });
  }

  const used = (usage) => usage.upload + usage.download;
  const tip = (profile) =>
    [
      profile.updatedAt && t('profiles.updated', { time: formatTime(profile.updatedAt) }),
      profile.kind === 'subscription' && profile.autoUpdate && t('profiles.autoUpdateEvery', { hours: profile.updateHours }),
    ]
      .filter(Boolean)
      .join(' · ');
</script>

{#if subject && app.tool.view === 'override'}
  <Override profile={subject} onback={back} />
{:else if subject && app.tool.view === 'nodes'}
  <ShareNodes profile={subject} onback={back} />
{:else}
  <Page title={t('page.profiles')}>
    {#snippet actions()}
      <button
        type="button"
        class="btn"
        disabled={updating || !subscriptions.length}
        onclick={() => subscriptions.forEach(update)}>{t('profiles.updateAll')}</button
      >
      <Menu label={t('profiles.addLabel')} triggerClass="btn primary" options={addOptions} onchange={addChosen}>
        {#snippet trigger()}{t('profiles.addLabel')}{/snippet}
      </Menu>
    {/snippet}

    <input bind:this={picker} type="file" accept=".yaml,.yml,.txt,.conf" hidden onchange={importFile} />

    {#if !app.profiles.length}
      <EmptyState icon="profiles" title={t('profiles.empty')} />
    {:else}
      {@const reorderable = app.profiles.length > 1}
      <section class="tbl auto" role="list">
        <div class="row t-prof thead" class:reorderable role="presentation">
          {#if reorderable}<span></span>{/if}
          <span>{t('table.name')}</span><span>{t('table.usage')}</span><span class="c-until">{t('table.expires')}</span><span
          ></span>
        </div>
        {#each app.profiles as profile (profile.id)}
          <div
            class="row t-prof"
            class:reorderable
            class:sel={profile.selected}
            class:dragging={dragged === profile.id}
            class:drop-target={target === profile.id && dragged !== profile.id}
            role="listitem"
            draggable={reorderable}
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
            in:rowIn={{ gap: 0 }}
            out:rowOut={{ gap: 0 }}
          >
            <button
              type="button"
              class="row-hit"
              aria-label={`${t('profiles.use')} · ${title(profile)}`}
              aria-pressed={profile.selected}
              title={tip(profile)}
              disabled={app.busy[`select:${profile.id}`]}
              onclick={() => !profile.selected && act(`select:${profile.id}`, 'select_profile', { id: profile.id })}
            ></button>
            {#if reorderable}<span class="grip" title={t('profiles.reorder')}><Icon name="grip" /></span>{/if}
            <span class="clip">{title(profile)}</span>
            <span class="usage">
              {#if profile.usage?.total}
                <span class="bar-track"
                  ><span class="bar-fill" style:width="{Math.min(100, (used(profile.usage) / profile.usage.total) * 100)}%"></span></span
                >
                <span class="val">{formatUsage(used(profile.usage), profile.usage.total)}</span>
              {:else if nodeCounts[profile.id] != null}
                <span class="val">{t('nodes.count', { count: nodeCounts[profile.id] })}</span>
              {/if}
            </span>
            <span class="val c-until">{profile.usage?.expire ? formatDate(profile.usage.expire) : ''}</span>
            <span class="cell-actions">
              {#if profile.kind === 'subscription'}
                <button
                  type="button"
                  class="icon-btn"
                  title={t('profiles.update')}
                  aria-label={t('profiles.update')}
                  disabled={app.busy[`update:${profile.id}`]}
                  onclick={() => update(profile)}><Icon name="refresh" class={app.busy[`update:${profile.id}`] ? 'spin' : ''} /></button
                >
              {/if}
              <Menu
                label={t('profiles.more')}
                triggerClass="icon-btn"
                options={moreOptions(profile)}
                onchange={(action) => moreActions[action](profile)}
              >
                {#snippet trigger()}<Icon name="moreH" />{/snippet}
              </Menu>
            </span>
          </div>
        {/each}
      </section>
    {/if}
  </Page>
{/if}

{#if dialog === 'url'}
  <Dialog title={t('profiles.add')} onclose={() => (dialog = null)}>
    <form id="add-url" class="dialog-form" onsubmit={add}>
      <!-- svelte-ignore a11y_autofocus -->
      <input
        class="in"
        type="url"
        bind:value={url}
        aria-label={t('profiles.url')}
        placeholder={t('profiles.url')}
        spellcheck="false"
        autofocus
      />
    </form>
    {#snippet actions()}
      <button type="submit" form="add-url" class="btn primary" disabled={!url.trim() || app.busy.add}>
        {#if app.busy.add}<span class="ring"></span>{/if}{t('profiles.addLabel')}
      </button>
    {/snippet}
  </Dialog>
{:else if dialog === 'links'}
  <Dialog title={t('profiles.import')} onclose={() => (dialog = null)}>
    <form id="import-links" class="dialog-form" onsubmit={importLinks}>
      <!-- svelte-ignore a11y_autofocus -->
      <textarea
        class="in code"
        rows="6"
        bind:value={links}
        aria-label={t('profiles.import')}
        placeholder={'vless://…\nss://…\ntrojan://…\nhysteria2://…'}
        spellcheck="false"
        autofocus
      ></textarea>
    </form>
    {#snippet actions()}
      <button type="submit" form="import-links" class="btn primary" disabled={!links.trim() || app.busy.import}
        >{t('profiles.importButton')}</button
      >
    {/snippet}
  </Dialog>
{/if}

{#if editing}
  <Dialog title={t('profiles.editTitle')} onclose={() => (editing = null)}>
    <form id="edit-profile" class="dialog-form" onsubmit={save}>
      <label class="form-field">
        <span>{t('profiles.name')}</span>
        <input class="in" bind:value={editing.name} spellcheck="false" />
      </label>
      {#if editing.kind === 'subscription'}
        <label class="form-field">
          <span>{t('profiles.url')}</span>
          <input class="in" type="url" bind:value={editing.url} spellcheck="false" />
        </label>
        <div class="form-row">
          <span class="grow">{t('profiles.autoUpdate')}</span>
          <Switch label={t('profiles.autoUpdate')} checked={editing.autoUpdate} onchange={(on) => (editing.autoUpdate = on)} />
        </div>
        <label class="form-row">
          <span class="grow">{t('profiles.updateHours')}</span>
          <input class="in number" type="number" min="1" max="720" bind:value={editing.updateHours} disabled={!editing.autoUpdate} />
        </label>
      {/if}
    </form>
    {#snippet actions()}
      <button type="submit" form="edit-profile" class="btn primary" disabled={!editing.name.trim() || app.busy.edit}
        >{t('common.save')}</button
      >
    {/snippet}
  </Dialog>
{/if}

{#if preview}
  <Dialog title={t('profiles.previewTitle', { name: preview.title })} wide onclose={() => (preview = null)}>
    <pre class="preview">{preview.config}</pre>
  </Dialog>
{/if}

{#if removing}
  <Dialog title={t('profiles.confirmDelete', { name: title(removing) })} onclose={() => (removing = null)}>
    {#snippet actions()}
      <button type="button" class="btn primary" onclick={remove}>{t('profiles.delete')}</button>
    {/snippet}
  </Dialog>
{/if}
