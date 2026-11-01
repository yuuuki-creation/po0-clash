<script>
  import { act, notify } from '../../lib/core.svelte.js';
  import { engine, fromLines, saveOptions, toLines } from '../../lib/engine.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Dialog from '../../lib/Dialog.svelte';
  import Icon from '../../lib/Icon.svelte';
  import Lines from '../../lib/form/Lines.svelte';
  import { rowIn, rowOut } from '../../lib/motion.svelte.js';
  import ScriptEditor from '../../lib/ScriptEditor.svelte';
  import { lineCount, loadScripts, scripts } from '../../lib/scripts.svelte.js';

  let editing = $state(null);
  let removing = $state(null);

  $effect(() => {
    loadScripts().catch((e) => notify(e));
  });

  async function remove() {
    const { id } = removing;
    removing = null;
    if ((await act(`script:remove:${id}`, 'remove_script', { id })) !== undefined) await loadScripts();
  }
</script>

<div class="group">
  <Lines
    label={t('opt.addedRules')}
    rows="8"
    placeholder="DOMAIN-SUFFIX,example.com,DIRECT"
    value={toLines(engine.options.addedRules)}
    onchange={(text) => {
      engine.options.addedRules = fromLines(text);
      saveOptions();
    }}
  />
</div>

<section>
  <h2 class="section-title">{t('script.library')}</h2>
  <div class="group">
    {#each scripts.list as script (script.id)}
      <div class="row" in:rowIn out:rowOut>
        <span class="grow clip">{script.name}</span>
        <span class="val">{t('script.lines', { count: lineCount(script) })}</span>
        <button
          type="button"
          class="icon-btn"
          title={t('script.edit')}
          aria-label={t('script.edit')}
          onclick={() => (editing = { script })}><Icon name="edit" /></button
        >
        <button
          type="button"
          class="icon-btn"
          title={t('script.delete')}
          aria-label={t('script.delete')}
          onclick={() => (removing = script)}><Icon name="trash" /></button
        >
      </div>
    {:else}
      <div class="row"><span class="val">{t('script.empty')}</span></div>
    {/each}
    <button type="button" class="row link-row" onclick={() => (editing = { script: null })}>{t('script.newEllipsis')}</button>
  </div>
</section>

{#if editing}
  <ScriptEditor script={editing.script} onclose={() => (editing = null)} />
{/if}

{#if removing}
  <Dialog title={t('script.confirmDelete', { name: removing.name })} onclose={() => (removing = null)}>
    <p>{t('script.deleteHint')}</p>
    {#snippet actions()}
      <button type="button" class="btn primary" onclick={remove}>{t('script.delete')}</button>
    {/snippet}
  </Dialog>
{/if}
