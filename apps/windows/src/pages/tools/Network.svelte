<script>
  import { engine, fromLines, saveOptions, toLines } from '../../lib/engine.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Choice from '../../lib/form/Choice.svelte';
  import Field from '../../lib/form/Field.svelte';
  import Lines from '../../lib/form/Lines.svelte';

  const o = $derived(engine.options);
  const set = (key) => (value) => {
    engine.options[key] = value;
    saveOptions();
  };
  const stacks = [
    { value: 'default', label: t('stack.default') },
    { value: 'system', label: 'System' },
    { value: 'gvisor', label: 'gVisor' },
    { value: 'mixed', label: 'Mixed' },
  ];
</script>

<h2 class="group-title">{t('opt.tun')}</h2>
<div class="list">
  <Choice
    label={t('opt.tunStack')}
    value={o.tunStack ?? 'default'}
    options={stacks}
    onchange={(stack) => set('tunStack')(stack === 'default' ? null : stack)}
  />
  <Lines
    label={t('opt.routeAddress')}
    hint={t('opt.routeAddressHint')}
    rows="3"
    value={toLines(o.tunRouteAddress)}
    onchange={(text) => set('tunRouteAddress')(fromLines(text))}
  />
  <Lines
    label={t('opt.dnsHijack')}
    hint={t('opt.dnsHijackHint')}
    rows="2"
    value={toLines(o.tunDnsHijack)}
    onchange={(text) => set('tunDnsHijack')(fromLines(text))}
  />
</div>

<h2 class="group-title">{t('opt.outbound')}</h2>
<div class="list">
  <Field
    label={t('opt.interfaceName')}
    hint={t('opt.interfaceNameHint')}
    value={o.interfaceName}
    onchange={set('interfaceName')}
  />
</div>
