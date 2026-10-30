<script>
  import { engine, fromLines, saveOptions, toLines } from '../../lib/engine.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Lines from '../../lib/form/Lines.svelte';
</script>

<div class="list">
  <Lines
    label={t('opt.addedRules')}
    hint={t('opt.addedRulesHint')}
    rows="8"
    value={toLines(engine.options.addedRules)}
    onchange={(text) => {
      engine.options.addedRules = fromLines(text);
      saveOptions();
    }}
  />
</div>

<h2 class="group-title">{t('opt.script')}</h2>
<div class="list">
  <div class="row"><span class="sub">{t('opt.scriptHint')}</span></div>
</div>
