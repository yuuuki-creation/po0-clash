<script>
  import Icon from './Icon.svelte';
  import { pop } from './motion.svelte.js';

  let { options, value, onchange, label, small = false, left = false, disabled = false, trigger } = $props();
  let open = $state(false);
  let root;

  const current = $derived(options.find((option) => option.value === value));

  function pick(option) {
    open = false;
    if (option.value !== value) onchange(option.value);
  }
</script>

<svelte:window
  onclick={(event) => open && !root.contains(event.target) && (open = false)}
  onkeydown={(event) => open && event.key === 'Escape' && (open = false)}
/>

<div class="menu" bind:this={root}>
  {#if trigger}
    <button type="button" title={label} aria-label={label} aria-haspopup="menu" aria-expanded={open} {disabled} onclick={() => (open = !open)}
      >{@render trigger()}</button
    >
  {:else}
    <button
      type="button"
      class="menu-button"
      class:small
      aria-label={label}
      aria-haspopup="menu"
      aria-expanded={open}
      {disabled}
      onclick={() => (open = !open)}
    >
      <span>{current?.label ?? '—'}</span><Icon name="updown-chevron" />
    </button>
  {/if}
  {#if open}
    <div class="menu-pop glass" class:left role="menu" aria-label={label} transition:pop={{ from: 0.94 }}>
      {#each options as option (option.value)}
        <button type="button" role="menuitemradio" aria-checked={option.value === value} onclick={() => pick(option)}>
          <span class="check">{#if option.value === value}<Icon name="check" />{/if}</span>
          <span class="grow"><span class="title">{option.label}</span>{#if option.detail}<span class="sub">{option.detail}</span>{/if}</span>
        </button>
      {/each}
    </div>
  {/if}
</div>
