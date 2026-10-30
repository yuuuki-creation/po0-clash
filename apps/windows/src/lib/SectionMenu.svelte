<script>
  import Icon from './Icon.svelte';

  let { label, sections, trigger } = $props();
  let open = $state(false);
  let root;
</script>

<svelte:window
  onclick={(event) => open && !root.contains(event.target) && (open = false)}
  onkeydown={(event) => open && event.key === 'Escape' && (open = false)}
/>

<div class="menu" bind:this={root}>
  <button type="button" title={label} aria-label={label} aria-haspopup="menu" aria-expanded={open} onclick={() => (open = !open)}
    >{@render trigger()}</button
  >
  {#if open}
    <div class="menu-pop glass" role="menu" aria-label={label}>
      {#each sections as section, i (section.title)}
        {#if i}<div class="menu-separator"></div>{/if}
        <span class="menu-heading">{section.title}</span>
        {#each section.options as option (option.value)}
          <button
            type="button"
            role="menuitemradio"
            aria-checked={option.value === section.value}
            onclick={() => option.value !== section.value && section.onchange(option.value)}
          >
            <span class="check">{#if option.value === section.value}<Icon name="check" />{/if}</span>
            <span class="grow"><span class="title">{option.label}</span></span>
          </button>
        {/each}
      {/each}
    </div>
  {/if}
</div>
