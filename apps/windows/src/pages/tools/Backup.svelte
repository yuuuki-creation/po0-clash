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

<h2 class="group-title">{t('backup.local')}</h2>
<div class="list">
  <div class="row tall">
    <div class="label"><span>{t('backup.toFile')}</span><span class="sub">{t('backup.toFileHint')}</span></div>
    <button type="button" class="pill" disabled={busy} onclick={backupToFile}>{t('backup.backup')}</button>
  </div>
  <div class="row tall">
    <div class="label"><span>{t('backup.fromFile')}</span><span class="sub">{t('backup.fromFileHint')}</span></div>
    <button type="button" class="pill" disabled={busy} onclick={() => (confirming = 'file')}>{t('backup.restore')}</button>
  </div>
</div>

<h2 class="group-title">{t('backup.restoring')}</h2>
<div class="list">
  <div class="row">
    <span class="label">{t('backup.scope')}</span>
    <div class="theme-seg">
      <Segmented
        small
        label={t('backup.scope')}
        value={scope}
        options={['all', 'profiles'].map((value) => ({ value, label: t(`backup.scope.${value}`) }))}
        onchange={(value) => (scope = value)}
      />
    </div>
  </div>
  <Choice
    label={t('backup.strategy')}
    hint={t(`backup.strategy.${s.restoreStrategy}Hint`)}
    value={s.restoreStrategy}
    options={['compatible', 'override'].map((value) => ({ value, label: t(`backup.strategy.${value}`) }))}
    onchange={(restoreStrategy) => updateSettings({ restoreStrategy })}
  />
</div>

<h2 class="group-title">WebDAV</h2>
<div class="list">
  <label class="row">
    <span class="label">{t('backup.davUrl')}</span>
    <input bind:value={dav.url} placeholder="https://dav.example.com/" spellcheck="false" />
  </label>
  <label class="row">
    <span class="label">{t('backup.davUser')}</span>
    <input bind:value={dav.user} spellcheck="false" autocomplete="off" />
  </label>
  <label class="row">
    <span class="label">{t('backup.davPassword')}</span>
    <input type="password" bind:value={dav.password} autocomplete="off" />
  </label>
  <label class="row">
    <span class="label">{t('backup.davFile')}</span>
    <input bind:value={dav.fileName} placeholder="backup.zip" spellcheck="false" />
  </label>
  <div class="row">
    <span class="label"></span>
    <button type="button" class="pill" disabled={!davFilled || busy} onclick={checkDav}>{t('backup.davCheck')}</button>
    <button type="button" class="pill filled" disabled={!davFilled || !davChanged} onclick={saveDav}>{t('backup.davSave')}</button>
  </div>
</div>
<p class="note">{t('backup.davHint')}</p>

<div class="list" style:margin-top="12px">
  <div class="row">
    <span class="label">{t('backup.toDav')}</span>
    <button type="button" class="pill" disabled={!s.webdav || davChanged || busy} onclick={backupToDav}>{t('backup.backup')}</button>
  </div>
  <div class="row">
    <span class="label">{t('backup.fromDav')}</span>
    <button type="button" class="pill" disabled={!s.webdav || davChanged || busy} onclick={() => (confirming = 'dav')}
      >{t('backup.restore')}</button
    >
  </div>
</div>

{#if confirming}
  <Dialog title={t('backup.confirm')} onclose={() => (confirming = null)}>
    <p class="sub">{t(`backup.confirm.${scope}`)} {t(`backup.strategy.${s.restoreStrategy}Hint`)}</p>
    {#snippet actions()}
      <button type="button" class="pill destructive" onclick={() => restore(confirming)}>{t('backup.restore')}</button>
    {/snippet}
  </Dialog>
{/if}
