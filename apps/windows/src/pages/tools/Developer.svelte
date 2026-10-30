<script>
  import { act, app, notify } from '../../lib/core.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Dialog from '../../lib/Dialog.svelte';
  import Toggle from '../../lib/form/Toggle.svelte';
  import { navigate } from '../../lib/motion.svelte.js';
  import { settings, updateSettings } from '../../lib/settings.svelte.js';

  let confirming = $state(null);

  const running = $derived(app.status?.engine.state === 'running');
  const captureLogs = $derived(settings.value.captureLogs);

  async function prune() {
    const removed = await act('dev:prune', 'prune_cache');
    if (removed !== undefined) notify(t('dev.pruned', { count: removed }));
  }

  async function confirm() {
    const what = confirming;
    confirming = null;
    if (what === 'crash') await act('dev:crash', 'crash_engine');
    else await act('dev:clear', 'clear_data');
  }

  const rows = $derived([
    { id: 'message', hint: t('dev.messageHint'), button: t('dev.show'), run: () => notify(t('dev.sample')) },
    {
      id: 'logs',
      hint: captureLogs ? t('dev.logsHint') : t('dev.logsOff'),
      button: t('dev.add'),
      disabled: !captureLogs,
      run: async () => (await act('dev:logs', 'add_test_logs')) !== undefined && notify(t('dev.logsAdded')),
    },
    {
      id: 'crash',
      hint: running ? t('dev.crashHint') : t('dev.crashOff'),
      button: t('dev.crashButton'),
      disabled: !running || app.busy['dev:crash'],
      run: () => (confirming = 'crash'),
    },
    { id: 'clear', hint: t('dev.clearHint'), button: t('dev.clearButton'), disabled: app.busy['dev:clear'], run: () => (confirming = 'clear') },
    { id: 'prune', hint: t('dev.pruneHint'), button: t('dev.pruneButton'), disabled: app.busy['dev:prune'], run: prune },
  ]);
</script>

<div class="list">
  <Toggle
    label={t('dev.mode')}
    hint={t('dev.modeHint')}
    checked={settings.value.developerMode}
    onchange={async (on) => {
      await updateSettings({ developerMode: on });
      if (!on) navigate('tools', null, 'back');
    }}
  />
</div>

<h2 class="group-title">{t('dev.options')}</h2>
<div class="list">
  {#each rows as row (row.id)}
    <div class="row tall">
      <div class="label"><span>{t(`dev.${row.id}`)}</span><span class="sub">{row.hint}</span></div>
      <button type="button" class="pill" disabled={row.disabled} onclick={row.run}>{row.button}</button>
    </div>
  {/each}
</div>

{#if confirming}
  <Dialog title={t(confirming === 'crash' ? 'dev.confirmCrash' : 'dev.confirmClear')} onclose={() => (confirming = null)}>
    <p class="sub">{t(confirming === 'crash' ? 'dev.confirmCrashHint' : 'dev.confirmClearHint')}</p>
    {#snippet actions()}
      <button type="button" class="pill destructive" onclick={confirm}
        >{t(confirming === 'crash' ? 'dev.crashConfirm' : 'dev.clearConfirm')}</button
      >
    {/snippet}
  </Dialog>
{/if}
