const SUCCESS_INTERVAL = 6 * 60 * 60 * 1000;
const FAILURE_INTERVAL = 5 * 60 * 1000;

export function createUpdateChecker({ fetchRelease, enabled, publish, failure, now = Date.now }) {
  let active = null;
  let lastSuccess = null;
  let lastAttempt = null;
  let retry = false;
  async function check(manual = false, networkChanged = false) {
    if (!manual && !enabled()) return;
    if (!manual && lastSuccess !== null && now() - lastSuccess < SUCCESS_INTERVAL) return;
    if (active) {
      if (networkChanged) retry = true;
      return active;
    }
    if (!manual && !networkChanged && lastAttempt !== null && now() - lastAttempt < FAILURE_INTERVAL) return;
    lastAttempt = now();
    active = (async () => {
      try {
        const release = await fetchRelease();
        lastSuccess = now();
        if (manual || enabled()) publish(release, manual);
      } catch (error) {
        if (manual) failure(error);
      } finally {
        active = null;
        if (retry) {
          retry = false;
          void check(false, true);
        }
      }
    })();
    return active;
  }
  return { check };
}
