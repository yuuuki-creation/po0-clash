<script>
  import { app } from './core.svelte.js';
  import { t } from './i18n.js';
  import Icon from './Icon.svelte';
  import StartButton from './StartButton.svelte';
  import WindowControls from './WindowControls.svelte';

  let { title, subtitle = '', onback, fill = false, form = false, actions, children } = $props();
</script>

<header class="toolbar" data-tauri-drag-region>
  {#if !app.sidebar}
    <button
      type="button"
      class="round-glass glass"
      title={t('window.sidebar')}
      aria-label={t('window.sidebar')}
      onclick={() => (app.sidebar = true)}><Icon name="sidebar" /></button
    >
  {/if}
  {#if onback}
    <button type="button" class="round-glass glass" title={t('window.back')} aria-label={t('window.back')} onclick={onback}
      ><Icon name="back" /></button
    >
  {/if}
  <div class="heading" data-tauri-drag-region>
    <h1>{title}</h1>
    {#if subtitle}<span class="sub">{subtitle}</span>{/if}
  </div>
  {#if actions}<div class="actions">{@render actions()}</div>{/if}
  <StartButton />
  <WindowControls />
</header>
<div class="scroll-edge" aria-hidden="true"></div>

<div class="content" class:fill class:form>
  {@render children()}
</div>
