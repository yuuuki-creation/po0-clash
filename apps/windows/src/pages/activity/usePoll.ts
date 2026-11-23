import { useEffect, useRef } from 'react';
import { pollVisible } from '../../lib/poll-visible';

export function usePoll(load: () => Promise<unknown>, active = true) {
  const latest = useRef(load);
  const pending = useRef<Promise<unknown> | null>(null);
  useEffect(() => {
    latest.current = load;
  });
  useEffect(() => {
    if (!active) return;
    return pollVisible(() => {
      pending.current ??= latest.current().finally(() => { pending.current = null; });
      return pending.current;
    });
  }, [active]);
}
