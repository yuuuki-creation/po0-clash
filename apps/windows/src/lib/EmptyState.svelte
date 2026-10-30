<script>
  import Icon from './Icon.svelte';

  let { icon, title, detail } = $props();
</script>

<div class="empty-state">
  <Icon name={icon} />
  <span class="empty-title">{title}</span>
  <span class="sub">{detail}</span>
</div>
