<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../../lib/core.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Dialog from '../../lib/Dialog.svelte';
  import Choice from '../../lib/form/Choice.svelte';
  import Segmented from '../../lib/Segmented.svelte';
  import { loadSettings, settings, updateSettings } from '../../lib/settings.svelte.js';

  const s = $derived(settings.value);
  let scope = $state('all');
  let confirming = $state(null);
  let dav = $state({ url: '', user: '', password: '', fileName: '' });

  $effect(() => {
    if (s.webdav) dav = { ...s.webdav };
  });

  const davFilled = $derived(/^https?:\/\//.test(dav.url.trim()));
  const davChanged = $derived(JSON.stringify(dav) !== JSON.stringify(s.webdav ?? {}));

  async function backupToFile() {
    const path = await act('backup:file', 'backup_to_file');
    if (path) notify(t('backup.saved', { path }));
  }

  async function restore(source) {
    confirming = null;
    const ok =
      source === 'file'
        ? await act('restore:file', 'restore_from_file', { scopeName: scope })
        : await act('restore:dav', 'restore_from_webdav', { scopeName: scope });
    if (ok === undefined || ok === false) return;
    await loadSettings();
    notify(t('backup.restored'));
  }

  async function checkDav() {
    if ((await act('dav:check', 'check_webdav', { dav: $state.snapshot(dav) })) !== undefined) notify(t('backup.davOk'));
  }

  async function saveDav() {
    await updateSettings({ webdav: { ...$state.snapshot(dav), url: dav.url.trim() } });
  }

  async function backupToDav() {
    if ((await act('backup:dav', 'backup_to_webdav')) !== undefined) notify(t('backup.davSaved'));
  }

  const busy = $derived(Object.keys(app.busy).some((key) => /^(backup|restore|dav):/.test(key)));
</script>

<section>
  <h2 class="section-title">{t('backup.local')}</h2>
  <div class="group">
    <div class="row">
      <span class="grow">{t('backup.toFile')}</span>
      <button type="button" class="btn" disabled={busy} onclick={backupToFile}>{t('backup.backup')}</button>
    </div>
    <div class="row">
      <span class="grow">{t('backup.fromFile')}</span>
      <button type="button" class="btn" disabled={busy} onclick={() => (confirming = 'file')}>{t('backup.restore')}</button>
    </div>
  </div>
</section>

<section>
  <h2 class="section-title">{t('backup.restoring')}</h2>
  <div class="group">
    <div class="row">
      <span class="grow">{t('backup.scope')}</span>
      <Segmented
        label={t('backup.scope')}
        value={scope}
        options={['all', 'profiles'].map((value) => ({ value, label: t(`backup.scope.${value}`) }))}
        onchange={(value) => (scope = value)}
      />
    </div>
    <Choice
      label={t('backup.strategy')}
      value={s.restoreStrategy}
      options={['compatible', 'override'].map((value) => ({ value, label: t(`backup.strategy.${value}`) }))}
      onchange={(restoreStrategy) => updateSettings({ restoreStrategy })}
    />
  </div>
</section>

<section>
  <h2 class="section-title">WebDAV</h2>
  <div class="group">
    <label class="row">
      <span class="grow">{t('backup.davUrl')}</span>
      <input class="in" bind:value={dav.url} placeholder="https://dav.example.com/" spellcheck="false" />
    </label>
    <label class="row">
      <span class="grow">{t('backup.davUser')}</span>
      <input class="in" bind:value={dav.user} spellcheck="false" autocomplete="off" />
    </label>
    <label class="row">
      <span class="grow">{t('backup.davPassword')}</span>
      <input class="in" type="password" bind:value={dav.password} autocomplete="off" />
    </label>
    <label class="row">
      <span class="grow">{t('backup.davFile')}</span>
      <input class="in" bind:value={dav.fileName} placeholder="backup.zip" spellcheck="false" />
    </label>
    <div class="row">
      <span class="grow"></span>
      <button type="button" class="btn" disabled={!davFilled || busy} onclick={checkDav}>{t('backup.davCheck')}</button>
      <button type="button" class="btn primary" disabled={!davFilled || !davChanged} onclick={saveDav}>{t('backup.davSave')}</button>
    </div>
  </div>
</section>

<div class="group">
  <div class="row">
    <span class="grow">{t('backup.toDav')}</span>
    <button type="button" class="btn" disabled={!s.webdav || davChanged || busy} onclick={backupToDav}>{t('backup.backup')}</button>
  </div>
  <div class="row">
    <span class="grow">{t('backup.fromDav')}</span>
    <button type="button" class="btn" disabled={!s.webdav || davChanged || busy} onclick={() => (confirming = 'dav')}
      >{t('backup.restore')}</button
    >
  </div>
</div>

{#if confirming}
  <Dialog title={t('backup.confirm')} onclose={() => (confirming = null)}>
    <p>{t(`backup.confirm.${scope}`)} {t(`backup.strategy.${s.restoreStrategy}Hint`)}</p>
    {#snippet actions()}
      <button type="button" class="btn primary" onclick={() => restore(confirming)}>{t('backup.restore')}</button>
    {/snippet}
  </Dialog>
{/if}
