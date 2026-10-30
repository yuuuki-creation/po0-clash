<script>
  import Switch from '../Switch.svelte';

  let { label, hint = '', checked, onchange, disabled = false } = $props();
</script>

<div class="row" class:tall={hint}>
  <div class="label"><span>{label}</span>{#if hint}<span class="sub">{hint}</span>{/if}</div>
  <Switch {label} {checked} {onchange} {disabled} />
</div>
