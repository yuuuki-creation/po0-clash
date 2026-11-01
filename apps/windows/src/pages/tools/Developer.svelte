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
    { id: 'message', button: t('dev.show'), run: () => notify(t('dev.sample')) },
    {
      id: 'logs',
      tip: captureLogs ? '' : t('dev.logsOff'),
      button: t('dev.add'),
      disabled: !captureLogs,
      run: async () => (await act('dev:logs', 'add_test_logs')) !== undefined && notify(t('dev.logsAdded')),
    },
    {
      id: 'crash',
      tip: running ? '' : t('dev.crashOff'),
      button: t('dev.crashButton'),
      disabled: !running || app.busy['dev:crash'],
      run: () => (confirming = 'crash'),
    },
    { id: 'clear', button: t('dev.clearButton'), disabled: app.busy['dev:clear'], run: () => (confirming = 'clear') },
    { id: 'prune', button: t('dev.pruneButton'), disabled: app.busy['dev:prune'], run: prune },
  ]);
</script>

<div class="group">
  <Toggle
    label={t('dev.mode')}
    checked={settings.value.developerMode}
    onchange={async (on) => {
      if ((await updateSettings({ developerMode: on })) && !on) navigate('tools', null, 'back');
    }}
  />
</div>

<section>
  <h2 class="section-title">{t('dev.options')}</h2>
  <div class="group">
    {#each rows as row (row.id)}
      <div class="row">
        <span class="grow">{t(`dev.${row.id}`)}</span>
        <button type="button" class="btn" title={row.tip} disabled={row.disabled} onclick={row.run}>{row.button}</button>
      </div>
    {/each}
  </div>
</section>

{#if confirming}
  <Dialog title={t(confirming === 'crash' ? 'dev.confirmCrash' : 'dev.confirmClear')} onclose={() => (confirming = null)}>
    <p>{t(confirming === 'crash' ? 'dev.confirmCrashHint' : 'dev.confirmClearHint')}</p>
    {#snippet actions()}
      <button type="button" class="btn primary" onclick={confirm}
        >{t(confirming === 'crash' ? 'dev.crashConfirm' : 'dev.clearConfirm')}</button
      >
    {/snippet}
  </Dialog>
{/if}
