<script>
  let { icon, name, style = 'standard', size = 18 } = $props();
  let failed = $state(false);

  const src = $derived.by(() => {
    const value = icon?.trim();
    if (!value || style === 'hidden') return null;
    if (value.startsWith('<svg') || value.startsWith('<?xml')) return `data:image/svg+xml;utf8,${encodeURIComponent(value)}`;
    if (/^(https?:|data:)/.test(value)) return value;
    return `data:image/png;base64,${value}`;
  });

  $effect(() => {
    src;
    failed = false;
  });
</script>

{#if src && !failed}
  <img class="group-icon" {src} alt="" width={size} height={size} onerror={() => (failed = true)} />
{/if}
{#if style !== 'iconOnly' || !src || failed}<span class="title">{name}</span>{/if}
