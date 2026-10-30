<script>
  import { formatBytes, formatDate, t } from './i18n.js';

  let { usage } = $props();
  const used = $derived(usage.upload + usage.download);
</script>

{#if usage.total}
  <div class="meter"><span style:width="{Math.min(100, (used / usage.total) * 100)}%"></span></div>
{/if}
<div class="usage sub">
  {#if usage.total}<span>{t('profiles.used', { used: formatBytes(used), total: formatBytes(usage.total) })}</span>{/if}
  {#if usage.expire}<span>{t('profiles.expire', { date: formatDate(usage.expire) })}</span>{/if}
</div>
