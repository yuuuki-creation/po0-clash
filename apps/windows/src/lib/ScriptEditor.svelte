<script>
  import { untrack } from 'svelte';
  import { act, app } from './core.svelte.js';
  import Dialog from './Dialog.svelte';
  import { t } from './i18n.js';
  import { loadScripts } from './scripts.svelte.js';

  const template = 'const main = (config) => {\n  return config;\n};\n';

  let { script = null, onclose, onsaved = () => {} } = $props();
  const initial = untrack(() => script);
  let name = $state(initial?.name ?? '');
  let content = $state(initial?.content ?? template);

  async function save(event) {
    event.preventDefault();
    const saved = await act('script:save', 'save_script', { script: { id: initial?.id ?? '', name, content } });
    if (!saved) return;
    await loadScripts();
    onsaved(saved);
    onclose();
  }
</script>

<Dialog title={initial ? t('script.edit') : t('script.new')} wide {onclose}>
  <form id="script-editor" class="stack" onsubmit={save}>
    <!-- svelte-ignore a11y_autofocus -->
    <input bind:value={name} aria-label={t('script.name')} placeholder={t('script.name')} spellcheck="false" autofocus />
    <textarea class="code" rows="16" bind:value={content} aria-label={t('script.content')} spellcheck="false"></textarea>
    <p class="sub">{t('script.hint')}</p>
  </form>
  {#snippet actions()}
    <button type="submit" form="script-editor" class="pill filled" disabled={!name.trim() || app.busy['script:save']}
      >{t('common.save')}</button
    >
  {/snippet}
</Dialog>
