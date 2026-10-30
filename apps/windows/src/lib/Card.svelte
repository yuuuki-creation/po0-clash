<script>
  import Icon from './Icon.svelte';

  let { title, icon, children } = $props();
</script>

<section class="card">
  <div class="card-title"><Icon name={icon} /><span>{title}</span></div>
  {@render children()}
</section>
