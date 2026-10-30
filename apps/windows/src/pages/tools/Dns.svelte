<script>
  import { engine, fromLines, fromPairs, saveOptions, toLines, toPairs } from '../../lib/engine.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Choice from '../../lib/form/Choice.svelte';
  import Field from '../../lib/form/Field.svelte';
  import Lines from '../../lib/form/Lines.svelte';
  import Toggle from '../../lib/form/Toggle.svelte';

  const o = $derived(engine.options);
  const d = $derived(engine.options.dns);
  const save = () => saveOptions();
  const setDns = (key) => (value) => {
    engine.options.dns[key] = value;
    save();
  };
  const setFilter = (key) => (value) => {
    engine.options.dns.fallbackFilter[key] = value;
    save();
  };
  const lines = (key, rows = 3) => ({
    rows,
    value: toLines(d[key]),
    onchange: (text) => setDns(key)(fromLines(text)),
  });
</script>

<div class="list">
  <Toggle
    label={t('opt.overrideDns')}
    hint={t('opt.overrideDnsHint')}
    checked={o.overrideDns}
    onchange={(on) => {
      engine.options.overrideDns = on;
      save();
    }}
  />
</div>

{#if o.overrideDns}
  <h2 class="group-title">DNS</h2>
  <div class="list">
    <Toggle label={t('opt.dnsEnable')} checked={d.enable} onchange={setDns('enable')} />
    <Field label={t('opt.dnsListen')} value={d.listen} placeholder="0.0.0.0:1053" onchange={setDns('listen')} />
    <Choice
      label={t('opt.enhancedMode')}
      value={d.enhancedMode}
      options={[
        { value: 'fakeIp', label: 'fake-ip' },
        { value: 'redirHost', label: 'redir-host' },
        { value: 'normal', label: 'normal' },
      ]}
      onchange={setDns('enhancedMode')}
    />
    <Field label={t('opt.fakeIpRange')} value={d.fakeIpRange} onchange={setDns('fakeIpRange')} />
    <Lines label={t('opt.fakeIpFilter')} hint={t('opt.linesHint')} {...lines('fakeIpFilter', 4)} />
  </div>

  <h2 class="group-title">{t('opt.servers')}</h2>
  <div class="list">
    <Lines label={t('opt.defaultNameserver')} {...lines('defaultNameserver', 2)} />
    <Lines label={t('opt.nameserver')} {...lines('nameserver')} />
    <Lines label={t('opt.fallback')} {...lines('fallback', 2)} />
    <Lines label={t('opt.proxyNameserver')} {...lines('proxyServerNameserver', 2)} />
    <Lines
      label={t('opt.policy')}
      hint={t('opt.policyHint')}
      rows="3"
      value={toPairs(d.nameserverPolicy)}
      onchange={(text) => setDns('nameserverPolicy')(fromPairs(text))}
    />
  </div>

  <h2 class="group-title">{t('opt.dnsBehavior')}</h2>
  <div class="list">
    <Toggle label={t('opt.preferH3')} checked={d.preferH3} onchange={setDns('preferH3')} />
    <Toggle label={t('opt.useHosts')} checked={d.useHosts} onchange={setDns('useHosts')} />
    <Toggle label={t('opt.useSystemHosts')} checked={d.useSystemHosts} onchange={setDns('useSystemHosts')} />
    <Toggle label={t('opt.respectRules')} checked={d.respectRules} onchange={setDns('respectRules')} />
    <Toggle label={t('opt.dnsIpv6')} checked={d.ipv6} onchange={setDns('ipv6')} />
  </div>

  <h2 class="group-title">{t('opt.fallbackFilter')}</h2>
  <div class="list">
    <Toggle label={t('opt.geoip')} checked={d.fallbackFilter.geoip} onchange={setFilter('geoip')} />
    <Field label={t('opt.geoipCode')} value={d.fallbackFilter.geoipCode} onchange={setFilter('geoipCode')} />
    <Lines
      label={t('opt.geosite')}
      rows="2"
      value={toLines(d.fallbackFilter.geosite)}
      onchange={(text) => setFilter('geosite')(fromLines(text))}
    />
    <Lines
      label={t('opt.ipcidr')}
      rows="2"
      value={toLines(d.fallbackFilter.ipcidr)}
      onchange={(text) => setFilter('ipcidr')(fromLines(text))}
    />
    <Lines
      label={t('opt.domain')}
      rows="3"
      value={toLines(d.fallbackFilter.domain)}
      onchange={(text) => setFilter('domain')(fromLines(text))}
    />
  </div>
{/if}
