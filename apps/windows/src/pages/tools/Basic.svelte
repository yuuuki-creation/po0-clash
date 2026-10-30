<script>
  import { engine, fromLines, fromPairs, saveOptions, toLines, toPairs } from '../../lib/engine.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Choice from '../../lib/form/Choice.svelte';
  import Field from '../../lib/form/Field.svelte';
  import Lines from '../../lib/form/Lines.svelte';
  import Toggle from '../../lib/form/Toggle.svelte';

  const o = $derived(engine.options);
  const set = (key) => (value) => {
    engine.options[key] = value;
    saveOptions();
  };
  const levels = ['debug', 'info', 'warning', 'error', 'silent'];
</script>

<h2 class="group-title">{t('opt.core')}</h2>
<div class="list">
  <Choice
    label={t('opt.logLevel')}
    value={o.logLevel}
    options={levels.map((value) => ({ value, label: value }))}
    onchange={set('logLevel')}
  />
  <Toggle label={t('opt.ipv6')} checked={o.ipv6} onchange={set('ipv6')} />
  <Toggle label={t('opt.unifiedDelay')} hint={t('opt.unifiedDelayHint')} checked={o.unifiedDelay} onchange={set('unifiedDelay')} />
  <Toggle label={t('opt.tcpConcurrent')} checked={o.tcpConcurrent} onchange={set('tcpConcurrent')} />
  <Choice
    label={t('opt.findProcess')}
    value={o.findProcessMode}
    options={['off', 'strict', 'always'].map((value) => ({ value, label: t(`find.${value}`) }))}
    onchange={set('findProcessMode')}
  />
  <Field label={t('opt.keepAlive')} type="number" min="0" value={o.keepAliveInterval} onchange={set('keepAliveInterval')} />
</div>

<h2 class="group-title">{t('opt.ports')}</h2>
<div class="list">
  <Field label={t('opt.mixedPort')} type="number" min="1" max="65535" value={o.mixedPort} onchange={set('mixedPort')} />
  <Field label={t('opt.socksPort')} type="number" min="0" max="65535" value={o.socksPort} onchange={set('socksPort')} />
  <Field label={t('opt.httpPort')} type="number" min="0" max="65535" value={o.httpPort} onchange={set('httpPort')} />
</div>
<p class="note">{t('opt.portHint')}</p>

<h2 class="group-title">{t('opt.inbound')}</h2>
<div class="list">
  <Toggle label={t('opt.allowLan')} hint={t('opt.allowLanHint')} checked={o.allowLan} onchange={set('allowLan')} />
  <Toggle
    label={t('opt.externalController')}
    hint={t('opt.externalControllerHint')}
    checked={o.externalController}
    onchange={set('externalController')}
  />
  <Lines
    label={t('opt.auth')}
    hint={t('opt.authHint')}
    rows="2"
    value={toLines(o.authentication)}
    onchange={(text) => set('authentication')(fromLines(text))}
  />
</div>

<h2 class="group-title">{t('opt.behavior')}</h2>
<div class="list">
  <Field label={t('opt.testUrl')} value={o.testUrl} onchange={set('testUrl')} />
  <Field label={t('opt.userAgent')} hint={t('opt.userAgentHint')} value={o.userAgent} onchange={set('userAgent')} />
  <Lines
    label={t('opt.hosts')}
    hint={t('opt.hostsHint')}
    rows="3"
    value={toPairs(o.hosts)}
    onchange={(text) => set('hosts')(fromPairs(text))}
  />
</div>
