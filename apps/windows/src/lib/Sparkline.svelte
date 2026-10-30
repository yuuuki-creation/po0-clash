<script>
  let { history } = $props();

  const points = (key, max) =>
    history.map((sample, i) => `${(i / Math.max(history.length - 1, 1)) * 100},${40 - (sample[key] / max) * 38}`).join(' ');
  const max = $derived(Math.max(1, ...history.flatMap((sample) => [sample.up, sample.down])));
</script>

<svg class="sparkline" viewBox="0 0 100 40" preserveAspectRatio="none" aria-hidden="true">
  {#if history.length > 1}
    <polyline class="down" points={points('down', max)} />
    <polyline class="up" points={points('up', max)} />
  {/if}
</svg>
