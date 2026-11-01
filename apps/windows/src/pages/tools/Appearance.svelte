<script>
  import { t } from '../../lib/i18n.js';
  import Choice from '../../lib/form/Choice.svelte';
  import Toggle from '../../lib/form/Toggle.svelte';
  import Icon from '../../lib/Icon.svelte';
  import Segmented from '../../lib/Segmented.svelte';
  import { settings, updateSettings } from '../../lib/settings.svelte.js';
  import { presets, toArgb, toHex } from '../../lib/theme.svelte.js';

  const variants = ['tonalSpot', 'fidelity', 'monochrome', 'neutral', 'vibrant', 'expressive', 'content', 'rainbow', 'fruitSalad'];
  const presetHex = presets.map(([, hex]) => hex);

  const s = $derived(settings.value);
  const colors = $derived(s.themeColors.map(toHex));
  let picker;
  let lastScale = $state(110);

  const label = (hex) => {
    const preset = presets.find(([, c]) => c === hex);
    return preset ? t(`color.${preset[0]}`) : t('color.custom', { hex });
  };

  function addColor(event) {
    const argb = toArgb(event.target.value);
    updateSettings({ themeColor: argb, themeColors: [...s.themeColors.filter((c) => c !== argb), argb] });
  }

  function removeColor(event, hex) {
    event.preventDefault();
    if (presetHex.includes(hex)) return;
    const argb = toArgb(hex);
    const themeColors = s.themeColors.filter((c) => c !== argb);
    updateSettings({ themeColors, themeColor: s.themeColor === argb ? toArgb(presetHex[0]) : s.themeColor });
  }

  function setScaled(on) {
    if (!on) lastScale = s.textScale ?? lastScale;
    updateSettings({ textScale: on ? lastScale : null });
  }
</script>

<div class="group">
  <div class="row">
    <span class="grow">{t('ap.mode')}</span>
    <Segmented
      label={t('ap.mode')}
      value={s.themeMode}
      options={['light', 'dark', 'system'].map((value) => ({ value, label: t(`ap.${value}`) }))}
      onchange={(themeMode) => updateSettings({ themeMode })}
    />
  </div>
  <Toggle label={t('ap.black')} checked={s.pureBlack} onchange={(pureBlack) => updateSettings({ pureBlack })} />
</div>

<section>
  <h2 class="section-title">{t('ap.color')}</h2>
  <div class="group">
    <div class="row">
      <span class="grow">{t('ap.accent')}</span>
      <div class="swatches">
        {#each colors as hex (hex)}
          {@const on = hex === toHex(s.themeColor)}
          <button
            type="button"
            class="swatch"
            class:on
            style:--swatch={hex}
            title={label(hex)}
            aria-label={label(hex)}
            aria-pressed={on}
            onclick={() => updateSettings({ themeColor: toArgb(hex) })}
            oncontextmenu={(event) => removeColor(event, hex)}
          ></button>
        {/each}
        <button type="button" class="swatch add" title={t('ap.addColor')} aria-label={t('ap.addColor')} onclick={() => picker.click()}
          ><Icon name="plus" /></button
        >
        <input bind:this={picker} type="color" value={toHex(s.themeColor)} hidden onchange={addColor} />
      </div>
    </div>
    <Choice
      label={t('ap.scheme')}
      value={s.schemeVariant}
      options={variants.map((value) => ({ value, label: t(`scheme.${value}`) }))}
      onchange={(schemeVariant) => updateSettings({ schemeVariant })}
    />
  </div>
</section>

<section>
  <h2 class="section-title">{t('ap.text')}</h2>
  <div class="group">
    <Toggle label={t('ap.scaled')} checked={s.textScale != null} onchange={setScaled} />
    <div class="row">
      <span class="scale-a" style:font-size="14px">A</span>
      <input
        type="range"
        min="80"
        max="150"
        step="5"
        aria-label={t('ap.scale')}
        disabled={s.textScale == null}
        value={s.textScale ?? lastScale}
        onchange={(event) => updateSettings({ textScale: Number(event.target.value) })}
      />
      <span class="scale-a" style:font-size="20px">A</span>
      <span class="val scale-value">{s.textScale ?? lastScale}%</span>
    </div>
  </div>
</section>
