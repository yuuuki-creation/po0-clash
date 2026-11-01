<script>
  import Menu from '../Menu.svelte';

  let { label, value, options, onchange } = $props();
</script>

<div class="row">
  <span class="grow">{label}</span>
  <Menu {label} {value} {options} {onchange} />
</div>
