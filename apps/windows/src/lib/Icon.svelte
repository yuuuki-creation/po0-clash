<script>
  let { name } = $props();

  const paths = {
    power: ['M12 3v8', 'M6.3 6.8a8 8 0 1 0 11.4 0'],
    globe: [
      'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18Z',
      'M3 12h18',
      'M12 3c2.5 2.6 3.7 5.6 3.7 9s-1.2 6.4-3.7 9c-2.5-2.6-3.7-5.6-3.7-9S9.5 5.6 12 3Z',
    ],
    list: ['M9 6h11', 'M9 12h11', 'M9 18h11', 'M4.5 6h.01', 'M4.5 12h.01', 'M4.5 18h.01'],
    shield: ['M12 3l7 3v5c0 4.6-3 8.4-7 10c-4-1.6-7-5.4-7-10V6Z', 'M8.8 12.2l2.2 2.2l4.2-4.4'],
    sliders: ['M4 7h10', 'M18 7h2', 'M16 5v4', 'M4 17h2', 'M10 17h10', 'M8 15v4'],
    check: ['M5 12.5l4.5 4.5L19 7.5'],
    chevron: ['M9 5l7 7l-7 7'],
  };
</script>

<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">
  {#each paths[name] as d (d)}
    <path {d} />
  {/each}
</svg>
