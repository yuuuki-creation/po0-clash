<script>
  import { t } from './i18n.js';

  let { id, actions, children } = $props();
</script>

<header class="page-header">
  <h1>{t(`page.${id}`)}</h1>
  {#if actions}
    <div class="toolbar glass">{@render actions()}</div>
  {/if}
</header>
{@render children()}
