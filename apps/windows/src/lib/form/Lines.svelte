<script>
  let { label, value, onchange, rows = 4, placeholder = '' } = $props();
</script>

<label class="row block">
  <span>{label}</span>
  <textarea class="in code" {rows} {value} {placeholder} spellcheck="false" onchange={(event) => onchange(event.target.value)}></textarea>
</label>
