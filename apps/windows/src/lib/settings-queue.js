export function createSettingsQueue({ read, write, publish, onError }) {
  let confirmed = null;
  let pending = [];
  let version = 0;
  let tail = Promise.resolve();

  const emit = () => publish(pending.reduce((value, intent) => ({ ...value, ...intent.patch }), confirmed));
  const enqueue = (run) => {
    const result = tail.then(run);
    tail = result.catch(() => {});
    return result;
  };
  const settled = async () => {
    let current;
    do {
      current = tail;
      await current;
    } while (current !== tail);
  };

  return {
    load() {
      return enqueue(async () => {
        confirmed = await read();
        emit();
      });
    },
    update(patch) {
      const intent = { version: ++version, patch: structuredClone(patch) };
      pending.push(intent);
      emit();
      const result = enqueue(async () => {
        let saved = false;
        try {
          confirmed ??= await read();
          const next = { ...confirmed, ...intent.patch };
          await write(next);
          confirmed = next;
          saved = true;
        } catch (error) {
          onError(error);
        }
        try {
          confirmed = await read();
        } catch (error) {
          onError(error);
        }
        pending = pending.filter((item) => item.version !== intent.version);
        emit();
        return saved;
      });
      return result.then(async (saved) => {
        await settled();
        return saved;
      });
    },
  };
}
