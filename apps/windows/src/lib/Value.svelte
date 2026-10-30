<script>
  import { cubicOut } from 'svelte/easing';
  import { Tween } from 'svelte/motion';
  import { motion } from './motion.svelte.js';

  let { text, size = '' } = $props();

  const parts = $derived.by(() => {
    const match = /^(\S+)\s+(.+)$/.exec(String(text));
    return match ? [match[1], match[2]] : [String(text), ''];
  });

  // Plain decimal numbers count to their new value; anything else (addresses, dashes) just changes.
  const numeric = $derived(/^\d+(\.\d+)?$/.test(parts[0]) ? Number(parts[0]) : null);
  const decimals = $derived(parts[0].split('.')[1]?.length ?? 0);
  const tween = new Tween(0, { easing: cubicOut });
  let unit = '';

  $effect(() => {
    if (numeric === null) return;
    const jump = unit !== parts[1];
    unit = parts[1];
    tween.set(numeric, { duration: jump ? 0 : motion(420) });
  });

  const shown = $derived(numeric === null ? parts[0] : tween.current.toFixed(decimals));
</script>

<div class="value">
  <span class="number {size}">{shown}</span>{#if parts[1]}<span class="unit">{parts[1]}</span>{/if}
</div>
