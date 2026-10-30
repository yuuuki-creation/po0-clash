<script>
  let { label, hint = '', value, onchange, rows = 4 } = $props();
</script>

<label class="row block">
  <span class="label"><span>{label}</span>{#if hint}<span class="sub">{hint}</span>{/if}</span>
  <textarea class="code" {rows} {value} spellcheck="false" onchange={(event) => onchange(event.target.value)}></textarea>
</label>
