<script>
  import Icon from './Icon.svelte';

  let { title, icon, span = false, accessory, children } = $props();
</script>

<section class="bento-card" class:span2={span} aria-label={title}>
  <div class="card-head">
    <span class="card-icon"><Icon name={icon} /></span>
    <span class="card-title">{title}</span>
    {#if accessory}<div class="card-acc">{@render accessory()}</div>{/if}
  </div>
  <div class="card-body">
    {@render children()}
  </div>
</section>
