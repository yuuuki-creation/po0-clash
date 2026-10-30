<script>
  import Icon from './Icon.svelte';

  let { title, icon, span = false, accessory, children } = $props();
</script>

<section class="card" class:span2={span} aria-label={title}>
  <div class="card-head">
    <Icon name={icon} /><span>{title}</span>
    {#if accessory}<div class="accessory">{@render accessory()}</div>{/if}
  </div>
  {@render children()}
</section>
