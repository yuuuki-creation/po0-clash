import { createContext, type ReactElement, useLayoutEffect, useState } from 'react';

export const DialogLifecycle = createContext<{ open: boolean; onExited: () => void } | null>(null);

export function DialogPresence({ children }: { children: ReactElement | null | false | undefined }) {
  const [retained, setRetained] = useState(children);
  useLayoutEffect(() => {
    if (children) setRetained(children);
  }, [children]);
  return (
    <DialogLifecycle.Provider value={{ open: !!children, onExited: () => !children && setRetained(null) }}>
      {children || retained || null}
    </DialogLifecycle.Provider>
  );
}
