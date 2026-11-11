// Follows Clash Verge Rev (GPL-3.0): src/components/base/virtual-list.tsx.
import { useVirtualizer } from '@tanstack/react-virtual';
import { type CSSProperties, type Key, type ReactNode, useRef } from 'react';

interface Props {
  count: number;
  estimateSize: number;
  getItemKey?: (index: number) => Key;
  renderItem: (index: number) => ReactNode;
  style?: CSSProperties;
  /** Rows all have `estimateSize` height, so none is measured. */
  fixed?: boolean;
}

export function VirtualList({ count, estimateSize, getItemKey, renderItem, style, fixed }: Props) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count,
    getScrollElement: () => parentRef.current,
    estimateSize: () => estimateSize,
    overscan: 8,
    getItemKey,
  });

  return (
    <div ref={parentRef} style={{ ...style, overflow: 'auto', minHeight: 0 }}>
      <div style={{ height: virtualizer.getTotalSize(), position: 'relative' }}>
        {virtualizer.getVirtualItems().map((item) => (
          <div
            key={item.key}
            data-index={item.index}
            ref={fixed ? undefined : virtualizer.measureElement}
            style={{ position: 'absolute', top: 0, left: 0, width: '100%', transform: `translateY(${item.start}px)` }}
          >
            {renderItem(item.index)}
          </div>
        ))}
      </div>
    </div>
  );
}

export const pageContentStyle: CSSProperties = {
  height: '100%',
  display: 'flex',
  flexDirection: 'column',
  overflow: 'hidden',
};

export const toolbarSx = { pt: 1, mb: 0.5, mx: '10px', minHeight: 36, display: 'flex', alignItems: 'center', gap: 1 };

export const selectSx = (theme: { palette: { mode: string } }) => ({
  width: 120,
  height: 33.375,
  flexShrink: 0,
  background: theme.palette.mode === 'light' ? '#fff' : undefined,
  '[role="combobox"]': { py: 0.65, fontSize: 14 },
});
