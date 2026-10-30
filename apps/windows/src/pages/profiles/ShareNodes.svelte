<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../../lib/core.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Dialog from '../../lib/Dialog.svelte';
  import Icon from '../../lib/Icon.svelte';
  import Page from '../../lib/Page.svelte';

  let { profile, onback } = $props();
  let nodes = $state([]);
  let renaming = $state(null);
  let removing = $state(null);

  const load = () =>
    invoke('share_nodes', { id: profile.id })
      .then((list) => (nodes = list))
      .catch((e) => notify(e));

  $effect(() => {
    load();
  });

  async function rename(event) {
    event.preventDefault();
    const { name, newName } = renaming;
    if (newName.trim() === name) {
      renaming = null;
      return;
    }
    if ((await act('node:rename', 'rename_share_node', { id: profile.id, name, newName })) === undefined) return;
    renaming = null;
    await load();
  }

  async function remove() {
    const { name } = removing;
    removing = null;
    if ((await act(`node:remove:${name}`, 'remove_share_node', { id: profile.id, name })) !== undefined) await load();
  }
</script>

<Page title={t('nodes.title')} subtitle={t('nodes.count', { count: nodes.length })} {onback} form>
  <div class="list">
    {#each nodes as node (node.name)}
      <div class="row">
        <span class="tag mono">{node.kind}</span>
        <span class="grow selectable">{node.name}</span>
        <button
          type="button"
          class="icon-button"
          title={t('nodes.rename')}
          aria-label={t('nodes.rename')}
          onclick={() => (renaming = { name: node.name, newName: node.name })}><Icon name="pencil" /></button
        >
        <button
          type="button"
          class="icon-button"
          title={nodes.length > 1 ? t('nodes.delete') : t('nodes.lastNode')}
          aria-label={t('nodes.delete')}
          disabled={nodes.length < 2 || app.busy[`node:remove:${node.name}`]}
          onclick={() => (removing = node)}><Icon name="trash" /></button
        >
      </div>
    {/each}
  </div>
  <p class="note">{t('nodes.hint')}</p>
</Page>

{#if renaming}
  <Dialog title={t('nodes.renameTitle')} onclose={() => (renaming = null)}>
    <form id="rename-node" onsubmit={rename}>
      <!-- svelte-ignore a11y_autofocus -->
      <input bind:value={renaming.newName} aria-label={t('nodes.name')} spellcheck="false" autofocus />
    </form>
    {#snippet actions()}
      <button type="submit" form="rename-node" class="pill filled" disabled={!renaming.newName.trim() || app.busy['node:rename']}
        >{t('nodes.rename')}</button
      >
    {/snippet}
  </Dialog>
{/if}

{#if removing}
  <Dialog title={t('nodes.confirmDelete', { name: removing.name })} onclose={() => (removing = null)}>
    {#snippet actions()}
      <button type="button" class="pill destructive" onclick={remove}>{t('nodes.delete')}</button>
    {/snippet}
  </Dialog>
{/if}
