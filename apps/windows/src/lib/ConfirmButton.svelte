<script>
  let { label, confirmLabel, onconfirm, disabled = false } = $props();
  let armed = $state(false);
  let timer;

  function click() {
    if (!armed) {
      armed = true;
      timer = setTimeout(() => (armed = false), 3000);
      return;
    }
    clearTimeout(timer);
    armed = false;
    onconfirm();
  }
</script>

<button type="button" class="danger" class:armed {disabled} onclick={click}>{armed ? confirmLabel : label}</button>
