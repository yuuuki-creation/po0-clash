<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../../lib/core.svelte.js';
  import { engine, saveOptions } from '../../lib/engine.svelte.js';
  import { formatBytes, formatTime, t } from '../../lib/i18n.js';
  import Choice from '../../lib/form/Choice.svelte';
  import Field from '../../lib/form/Field.svelte';
  import Toggle from '../../lib/form/Toggle.svelte';

  let files = $state([]);
  const load = () => invoke('geo_files').then((list) => (files = list));
  $effect(() => {
    load();
  });

  const o = $derived(engine.options);
  const set = (key) => (value) => {
    engine.options[key] = value;
    saveOptions();
  };
  const setUrl = (key) => (value) => {
    engine.options.geoxUrl[key] = value;
    saveOptions();
  };

  async function update() {
    if ((await act('geo', 'update_geo')) === undefined) return;
    await load();
    notify(t('opt.geoUpdated'));
  }
</script>

<h2 class="group-title">{t('opt.geo')}</h2>
<div class="list">
  {#each files as file (file.name)}
    <div class="row">
      <div class="label">
        <span>{file.name}</span>
        <span class="sub mono">
          {file.size != null ? formatBytes(file.size) : t('opt.notDownloaded')}{file.modified
            ? ` · ${formatTime(file.modified)}`
            : ''}
        </span>
      </div>
    </div>
  {/each}
  <div class="row">
    <span class="label"></span>
    <button type="button" class="pill" disabled={app.busy.geo} onclick={update}>{t('opt.updateGeo')}</button>
  </div>
</div>

<div class="list" style:margin-top="12px">
  <Choice
    label={t('opt.geoLoader')}
    value={o.geodataLoader}
    options={['standard', 'memconservative'].map((value) => ({ value, label: t(`loader.${value}`) }))}
    onchange={set('geodataLoader')}
  />
  <Toggle label={t('opt.geoAutoUpdate')} checked={o.geoAutoUpdate} onchange={set('geoAutoUpdate')} />
  <Field label={t('opt.geoInterval')} type="number" min="1" value={o.geoUpdateInterval} onchange={set('geoUpdateInterval')} />
</div>

<h2 class="group-title">{t('opt.geoUrls')}</h2>
<div class="list">
  <Field label="GeoIP" value={o.geoxUrl.geoip} onchange={setUrl('geoip')} />
  <Field label="GeoSite" value={o.geoxUrl.geosite} onchange={setUrl('geosite')} />
  <Field label="MMDB" value={o.geoxUrl.mmdb} onchange={setUrl('mmdb')} />
  <Field label="ASN" value={o.geoxUrl.asn} onchange={setUrl('asn')} />
</div>
