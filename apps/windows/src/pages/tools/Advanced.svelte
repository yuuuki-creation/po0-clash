<script>
  import { flip } from 'svelte/animate';
  import { act, notify } from '../../lib/core.svelte.js';
  import { engine, fromLines, saveOptions, toLines } from '../../lib/engine.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Dialog from '../../lib/Dialog.svelte';
  import Icon from '../../lib/Icon.svelte';
  import Lines from '../../lib/form/Lines.svelte';
  import { motion, rise } from '../../lib/motion.svelte.js';
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

<div class="list">
  <Lines
    label={t('opt.addedRules')}
    hint={t('opt.addedRulesHint')}
    rows="8"
    value={toLines(engine.options.addedRules)}
    onchange={(text) => {
      engine.options.addedRules = fromLines(text);
      saveOptions();
    }}
  />
</div>

<h2 class="group-title">{t('script.library')}</h2>
<div class="list">
  {#each scripts.list as script (script.id)}
    <div class="row" animate:flip={{ duration: motion(260) }} transition:rise>
      <span class="row-icon"><Icon name="doc" /></span>
      <div class="grow stacked">
        <span class="title">{script.name}</span>
        <span class="sub">{t('script.lines', { count: lineCount(script) })}</span>
      </div>
      <button
        type="button"
        class="icon-button"
        title={t('script.edit')}
        aria-label={t('script.edit')}
        onclick={() => (editing = { script })}><Icon name="pencil" /></button
      >
      <button
        type="button"
        class="icon-button"
        title={t('script.delete')}
        aria-label={t('script.delete')}
        onclick={() => (removing = script)}><Icon name="trash" /></button
      >
    </div>
  {:else}
    <div class="row"><span class="sub">{t('script.empty')}</span></div>
  {/each}
  <button type="button" class="row link-row" onclick={() => (editing = { script: null })}>{t('script.newEllipsis')}</button>
</div>
<p class="note">{t('script.libraryHint')}</p>

{#if editing}
  <ScriptEditor script={editing.script} onclose={() => (editing = null)} />
{/if}

{#if removing}
  <Dialog title={t('script.confirmDelete', { name: removing.name })} onclose={() => (removing = null)}>
    <p class="sub">{t('script.deleteHint')}</p>
    {#snippet actions()}
      <button type="button" class="pill destructive" onclick={remove}>{t('script.delete')}</button>
    {/snippet}
  </Dialog>
{/if}
