<script>
  import { t } from '../../lib/i18n.js';
  import Icon from '../../lib/Icon.svelte';
  import Menu from '../../lib/Menu.svelte';
  import Segmented from '../../lib/Segmented.svelte';
  import Switch from '../../lib/Switch.svelte';
  import { appearance, presets } from '../../lib/theme.svelte.js';

  let picker;

  const same = (a, b) => a.toUpperCase() === b.toUpperCase();

  function addColor(event) {
    const color = event.target.value.toUpperCase();
    if (!appearance.custom.some((c) => same(c, color)) && !presets.some(([, c]) => same(c, color))) {
      appearance.custom = [...appearance.custom, color];
    }
    appearance.accent = color;
  }

  function removeColor(event, color) {
    event.preventDefault();
    appearance.custom = appearance.custom.filter((c) => !same(c, color));
    if (same(appearance.accent, color)) appearance.accent = presets[0][1];
  }
</script>

<div class="list">
  <div class="row">
    <span class="label">{t('ap.mode')}</span>
    <div class="theme-seg">
      <Segmented
        small
        label={t('ap.mode')}
        value={appearance.mode}
        options={['light', 'dark', 'system'].map((value) => ({ value, label: t(`ap.${value}`) }))}
        onchange={(mode) => (appearance.mode = mode)}
      />
    </div>
  </div>
  <div class="row tall">
    <div class="label"><span>{t('ap.black')}</span><span class="sub">{t('ap.blackHint')}</span></div>
    <Switch label={t('ap.black')} checked={appearance.black} onchange={(on) => (appearance.black = on)} />
  </div>
</div>

<h2 class="group-title">{t('ap.color')}</h2>
<div class="list">
  <div class="row tall">
    <span class="label">{t('ap.accent')}</span>
    <div class="swatches">
      {#each presets as [name, color] (name)}
        <button
          type="button"
          class="swatch"
          class:on={same(appearance.accent, color)}
          style:background={color}
          style:--swatch={color}
          title={t(`color.${name}`)}
          aria-label={t(`color.${name}`)}
          aria-pressed={same(appearance.accent, color)}
          onclick={() => (appearance.accent = color)}
        ></button>
      {/each}
      {#each appearance.custom as color (color)}
        <button
          type="button"
          class="swatch"
          class:on={same(appearance.accent, color)}
          style:background={color}
          style:--swatch={color}
          title={t('color.custom', { hex: color })}
          aria-label={t('color.custom', { hex: color })}
          aria-pressed={same(appearance.accent, color)}
          onclick={() => (appearance.accent = color)}
          oncontextmenu={(event) => removeColor(event, color)}
        ></button>
      {/each}
      <button type="button" class="swatch add" title={t('ap.addColor')} aria-label={t('ap.addColor')} onclick={() => picker.click()}
        ><Icon name="plus" /></button
      >
      <input bind:this={picker} type="color" value={appearance.accent} hidden onchange={addColor} />
    </div>
  </div>
  <div class="row">
    <span class="label">{t('ap.scheme')}</span>
    <Menu
      label={t('ap.scheme')}
      value={appearance.scheme}
      options={['standard', 'vivid', 'muted'].map((value) => ({ value, label: t(`scheme.${value}`) }))}
      onchange={(scheme) => (appearance.scheme = scheme)}
    />
  </div>
</div>
<p class="note">{t('ap.colorHint')}</p>

<h2 class="group-title">{t('ap.text')}</h2>
<div class="list">
  <div class="row">
    <span class="label">{t('ap.scaled')}</span>
    <Switch label={t('ap.scaled')} checked={appearance.scaled} onchange={(on) => (appearance.scaled = on)} />
  </div>
  <div class="row tall">
    <span class="sub strong" style:font-size="11px">A</span>
    <input
      type="range"
      min="80"
      max="140"
      step="5"
      aria-label={t('ap.scale')}
      disabled={!appearance.scaled}
      value={appearance.scale}
      onchange={(event) => (appearance.scale = Number(event.target.value))}
    />
    <span class="sub strong" style:font-size="17px">A</span>
    <span class="sub mono scale-value">{appearance.scale}%</span>
  </div>
</div>
