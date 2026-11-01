<script>
  import Switch from '../Switch.svelte';

  let { label, checked, onchange, disabled = false } = $props();
</script>

<div class="row">
  <span class="grow">{label}</span>
  <Switch {label} {checked} {onchange} {disabled} />
</div>
