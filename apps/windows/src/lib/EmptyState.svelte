<script>
  import Icon from './Icon.svelte';

  let { icon, title } = $props();
</script>

<div class="empty-state">
  <Icon name={icon} />
  <span>{title}</span>
</div>
