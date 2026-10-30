<script>
  let { text, size = '' } = $props();

  const parts = $derived.by(() => {
    const match = /^(\S+)\s+(.+)$/.exec(String(text));
    return match ? [match[1], match[2]] : [String(text), ''];
  });
</script>

<div class="value">
  <span class="number {size}">{parts[0]}</span>{#if parts[1]}<span class="unit">{parts[1]}</span>{/if}
</div>
