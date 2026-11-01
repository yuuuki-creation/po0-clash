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

<section>
  <h2 class="section-title">{t('opt.tun')}</h2>
  <div class="group">
    <Choice
      label={t('opt.tunStack')}
      value={o.tunStack ?? 'default'}
      options={stacks}
      onchange={(stack) => set('tunStack')(stack === 'default' ? null : stack)}
    />
    <Lines
      label={t('opt.routeAddress')}
      rows="3"
      placeholder="0.0.0.0/1"
      value={toLines(o.tunRouteAddress)}
      onchange={(text) => set('tunRouteAddress')(fromLines(text))}
    />
    <Lines
      label={t('opt.dnsHijack')}
      rows="2"
      placeholder="any:53"
      value={toLines(o.tunDnsHijack)}
      onchange={(text) => set('tunDnsHijack')(fromLines(text))}
    />
  </div>
</section>

<section>
  <h2 class="section-title">{t('opt.outbound')}</h2>
  <div class="group">
    <Field
      label={t('opt.interfaceName')}
      value={o.interfaceName}
      onchange={set('interfaceName')}
    />
  </div>
</section>
