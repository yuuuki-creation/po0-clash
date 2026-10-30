<script>
  import Menu from '../Menu.svelte';

  let { label, hint = '', value, options, onchange } = $props();
</script>

<div class="row" class:tall={hint}>
  <div class="label"><span>{label}</span>{#if hint}<span class="sub">{hint}</span>{/if}</div>
  <Menu {label} {value} {options} {onchange} />
</div>
