<script>
  let { label, value, onchange, type = 'text', placeholder = '', min, max } = $props();
</script>

<label class="row">
  <span class="grow">{label}</span>
  <input
    {type}
    class="in"
    class:number={type === 'number'}
    {min}
    {max}
    {placeholder}
    {value}
    spellcheck="false"
    onchange={(event) => onchange(type === 'number' ? Number(event.target.value) || 0 : event.target.value.trim())}
  />
</label>
