<script>
  import Icon from './Icon.svelte';

  let { title, icon, wide = false, children } = $props();
</script>

<section class="card" class:wide>
  <div class="card-title"><Icon name={icon} /><span>{title}</span></div>
  {@render children()}
</section>
