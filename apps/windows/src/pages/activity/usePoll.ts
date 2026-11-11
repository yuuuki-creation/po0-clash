import { useEffect, useRef } from 'react';

export function usePoll(load: () => Promise<unknown>, active = true) {
  const latest = useRef(load);
  useEffect(() => {
    latest.current = load;
  });
  useEffect(() => {
    if (!active) return;
    const tick = () => {
      if (!document.hidden) latest.current().catch(() => {});
    };
    tick();
    const timer = setInterval(tick, 1000);
    return () => clearInterval(timer);
  }, [active]);
}
