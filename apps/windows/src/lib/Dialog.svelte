<script>
  import { t } from './i18n.js';
  import { dialogIn, dialogOut, scrimIn, scrimOut } from './motion.svelte.js';
  import { portal } from './popup.js';

  let { title, onclose, wide = false, children, actions } = $props();
</script>

<svelte:window onkeydown={(event) => event.key === 'Escape' && onclose()} />

<div class="overlay" use:portal>
  <button type="button" class="scrim" tabindex="-1" aria-label={t('common.cancel')} onclick={onclose} in:scrimIn|global out:scrimOut|global
  ></button>
  <div class="dialog" class:wide role="dialog" aria-modal="true" aria-label={title} in:dialogIn|global out:dialogOut|global>
    <h2>{title}</h2>
    {#if children}<div class="dialog-body">{@render children()}</div>{/if}
    <div class="dialog-actions">
      {#if actions}
        <button type="button" class="btn" onclick={onclose}>{t('common.cancel')}</button>
        {@render actions()}
      {:else}
        <!-- svelte-ignore a11y_autofocus -->
        <button type="button" class="btn primary" onclick={onclose} autofocus>{t('common.ok')}</button>
      {/if}
    </div>
  </div>
</div>
