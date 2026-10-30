<script>
  let { options, value, onchange, disabled = false, label } = $props();
</script>

<div class="segmented" role="radiogroup" aria-label={label}>
  {#each options as option (option.value)}
    <button
      type="button"
      role="radio"
      aria-checked={value === option.value}
      class:selected={value === option.value}
      {disabled}
      onclick={() => value !== option.value && onchange(option.value)}>{option.label}</button
    >
  {/each}
</div>
