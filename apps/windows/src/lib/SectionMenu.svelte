<script>
  import Icon from './Icon.svelte';
  import Popup from './Popup.svelte';

  let { label, sections, trigger, triggerClass = 'icon-btn', title } = $props();
  let open = $state(false);
  let button = $state();

  function pick(section, option) {
    if (section.close) open = false;
    if (option.value !== section.value) section.onchange(option.value);
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
  onclick={() => (open = !open)}>{@render trigger()}</button
>
{#if open}
  <Popup anchor={button} {label} onclose={() => (open = false)}>
    {#each sections as section, i (section.title ?? i)}
      {#if i}<div class="menu-sep"></div>{/if}
      {#if section.title}<span class="menu-heading">{section.title}</span>{/if}
      {#each section.options as option (option.value)}
        <button
          type="button"
          role="menuitemradio"
          aria-checked={option.value === section.value}
          disabled={option.disabled}
          onclick={() => pick(section, option)}
        >
          <span class="clip label">{option.label}</span>
          {#if option.detail}<span class="val">{option.detail}</span>{/if}
          {#if section.value != null}
            <span class="check-slot">{#if option.value === section.value}<Icon name="check" class="check" />{/if}</span>
          {/if}
        </button>
      {/each}
    {/each}
  </Popup>
{/if}
