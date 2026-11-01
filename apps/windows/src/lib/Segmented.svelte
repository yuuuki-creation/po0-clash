<script>
  let { options, value, onchange, disabled = false, label } = $props();
  const index = $derived(options.findIndex((option) => option.value === value));
</script>

<div class="seg" role="radiogroup" aria-label={label} style:--n={options.length} style:--i={Math.max(0, index)}>
  {#if index >= 0}<span class="seg-thumb"></span>{/if}
  {#each options as option (option.value)}
    <button
      type="button"
      role="radio"
      aria-checked={value === option.value}
      {disabled}
      onclick={() => value !== option.value && onchange(option.value)}>{option.label}</button
    >
  {/each}
</div>
