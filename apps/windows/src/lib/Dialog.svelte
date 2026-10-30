<script>
  import { t } from './i18n.js';

  let { title, onclose, children, actions } = $props();
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onclose()} />

<div class="scrim" role="presentation" onclick={(event) => event.target === event.currentTarget && onclose()}>
  <div class="dialog glass" role="dialog" aria-modal="true" aria-label={title}>
    <h2>{title}</h2>
    {@render children?.()}
    <div class="actions">
      {#if actions}
        <button type="button" class="pill plain" onclick={onclose}>{t('common.cancel')}</button>
        {@render actions()}
      {:else}
        <!-- svelte-ignore a11y_autofocus -->
        <button type="button" class="pill filled" onclick={onclose} autofocus>{t('common.ok')}</button>
      {/if}
    </div>
  </div>
</div>
