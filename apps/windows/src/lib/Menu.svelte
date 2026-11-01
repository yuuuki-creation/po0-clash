<script>
  import Icon from './Icon.svelte';
  import Popup from './Popup.svelte';

  let { options, value = null, onchange, label, disabled = false, trigger, triggerClass = 'btn select', title } = $props();
  let open = $state(false);
  let button = $state();

  const current = $derived(options.find((option) => option.value === value));

  function pick(option) {
    open = false;
    if (option.value !== value) onchange(option.value);
  }
</script>

<button
  bind:this={button}
  type="button"
  class={triggerClass}
  title={title ?? label}
  aria-label={label}
  aria-haspopup="menu"
  aria-expanded={open}
  {disabled}
  onclick={() => (open = !open)}
>
  {#if trigger}
    {@render trigger()}
  {:else}
    <span class="clip">{current?.label ?? '—'}</span><Icon name="chevDown" class="chev-d" />
  {/if}
</button>
{#if open}
  <Popup anchor={button} {label} onclose={() => (open = false)}>
    {#each options as option (option.value)}
      <button
        type="button"
        role="menuitemradio"
        class:danger={option.danger}
        aria-checked={option.value === value}
        disabled={option.disabled}
        onclick={() => pick(option)}
      >
        <span class="clip">{option.label}</span>
        {#if option.value === value}<Icon name="check" class="check" />{/if}
      </button>
    {/each}
  </Popup>
{/if}
