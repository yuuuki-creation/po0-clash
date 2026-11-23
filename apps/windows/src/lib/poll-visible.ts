export function pollVisible(load: () => Promise<unknown>, interval = 1000) {
  let stopped = false;
  let loading = false;
  let timer: ReturnType<typeof setTimeout> | undefined;

  async function tick() {
    clearTimeout(timer);
    if (stopped || document.hidden || loading) return;
    loading = true;
    try {
      await load();
    } catch {
      // A failed sample should not stop polling.
    } finally {
      loading = false;
      if (!stopped && !document.hidden) timer = setTimeout(tick, interval);
    }
  }

  document.addEventListener('visibilitychange', tick);
  timer = setTimeout(tick, 0);
  return () => {
    stopped = true;
    clearTimeout(timer);
    document.removeEventListener('visibilitychange', tick);
  };
}
