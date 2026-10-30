<script>
  let { label, hint = '', value, onchange, type = 'text', placeholder = '', min, max } = $props();
</script>

<label class="row" class:tall={hint}>
  <span class="label"><span>{label}</span>{#if hint}<span class="sub">{hint}</span>{/if}</span>
  <input
    {type}
    class:number={type === 'number'}
    {min}
    {max}
    {placeholder}
    {value}
    spellcheck="false"
    onchange={(event) => onchange(type === 'number' ? Number(event.target.value) || 0 : event.target.value.trim())}
  />
</label>
