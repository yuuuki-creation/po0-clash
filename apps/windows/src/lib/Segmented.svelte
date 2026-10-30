<script>
  let { options, value, onchange, disabled = false, label, small = false } = $props();
  let buttons = $state({});
  let thumb = $state(null);
  let placed = $state(false);

  $effect(() => {
    const button = buttons[value];
    if (!button) return (thumb = null);
    const place = () => (thumb = { left: button.offsetLeft, width: button.offsetWidth });
    place();
    requestAnimationFrame(() => (placed = true));
    const observer = new ResizeObserver(place);
    observer.observe(button.parentElement);
    return () => observer.disconnect();
  });
</script>

<div class="seg" class:small role="radiogroup" aria-label={label}>
  {#if thumb}
    <span class="seg-thumb" class:placed style:transform="translateX({thumb.left}px)" style:width="{thumb.width}px"></span>
  {/if}
  {#each options as option (option.value)}
    <button
      bind:this={buttons[option.value]}
      type="button"
      role="radio"
      aria-checked={value === option.value}
      class:on={value === option.value}
      {disabled}
      onclick={() => value !== option.value && onchange(option.value)}>{option.label}</button
    >
  {/each}
</div>
