<script>
  import { fade } from 'svelte/transition';
  import { t } from './i18n.js';
  import { motion, pop } from './motion.svelte.js';

  let { title, onclose, wide = false, children, actions } = $props();
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onclose()} />

<div class="scrim" role="presentation" transition:fade|global={{ duration: motion(160) }} onclick={(event) => event.target === event.currentTarget && onclose()}>
  <div class="dialog glass" class:wide transition:pop|global={{ from: 0.94, y: 8, duration: 220 }} role="dialog" aria-modal="true" aria-label={title}>
    <h2>{title}</h2>
    {@render children?.()}
    <div class="actions">
      {#if actions}
        <button type="button" class="pill" onclick={onclose}>{t('common.cancel')}</button>
        {@render actions()}
      {:else}
        <!-- svelte-ignore a11y_autofocus -->
        <button type="button" class="pill filled" onclick={onclose} autofocus>{t('common.ok')}</button>
      {/if}
    </div>
  </div>
</div>
