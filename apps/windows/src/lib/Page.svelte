<script>
  import { app } from './core.svelte.js';
  import { t } from './i18n.js';
  import Icon from './Icon.svelte';
  import WindowControls from './WindowControls.svelte';

  let { title, subtitle = '', onback, fill = false, actions, children } = $props();
</script>

<header class="toolbar" data-tauri-drag-region>
  <div class="group glass">
    <button
      type="button"
      title={t('window.sidebar')}
      aria-label={t('window.sidebar')}
      aria-pressed={app.sidebar}
      onclick={() => (app.sidebar = !app.sidebar)}><Icon name="sidebar" /></button
    >
  </div>
  {#if onback}
    <div class="group glass">
      <button type="button" title={t('window.back')} aria-label={t('window.back')} onclick={onback}
        ><Icon name="back" /></button
      >
    </div>
  {/if}
  <div class="heading" data-tauri-drag-region>
    <h1>{title}</h1>
    {#if subtitle}<span class="sub">{subtitle}</span>{/if}
  </div>
  {#if actions}<div class="actions">{@render actions()}</div>{/if}
  <WindowControls />
</header>
<div class="scroll-edge" aria-hidden="true"></div>

<div class="content" class:fill>
  {@render children()}
</div>
